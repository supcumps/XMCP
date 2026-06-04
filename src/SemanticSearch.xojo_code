#tag Class
Protected Class SemanticSearch
	#tag Method, Flags = &h0
		Sub Constructor(embeddingUrl As String, dbPath As String)
		  mEmbeddingUrl = embeddingUrl
		  mDbPath = dbPath
		  mAvailable = False

		  Var dbFile As New FolderItem(dbPath, FolderItem.PathModes.Native)
		  If dbFile = Nil Or Not dbFile.Exists Then Return

		  mDB = New SQLiteDatabase
		  mDB.DatabaseFile = dbFile
		  Try
		    mDB.Connect
		  Catch e As DatabaseException
		    mDB = Nil
		    Return
		  End Try

		  // Performance pragmas: WAL mode for non-blocking reads, memory-mapped I/O,
		  // and a 64 MB page cache so the embedding BLOBs stay warm between searches.
		  Try
		    mDB.ExecuteSQL("PRAGMA journal_mode=WAL")
		    mDB.ExecuteSQL("PRAGMA mmap_size=268435456")
		    mDB.ExecuteSQL("PRAGMA cache_size=-65536")
		  Catch
		    // Non-fatal; continue with defaults.
		  End Try

		  // Probe the embedding server.
		  Var testEmb As MemoryBlock = FetchEmbedding("test")
		  If testEmb = Nil Then
		    mDB.Close
		    mDB = Nil
		    Return
		  End If

		  mAvailable = True

		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub Destructor()
		  If mDB <> Nil Then
		    mDB.Close
		    mDB = Nil
		  End If
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function Available() As Boolean
		  Return mAvailable

		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function Search(query As String, maxResults As Integer) As String
		  If Not mAvailable Then Return ""
		  If mDB = Nil Then Return ""

		  // --- Cache check (#13) ---
		  Var cacheKey As String = query + "|" + maxResults.ToString
		  If mCache <> Nil And mCache.HasKey(cacheKey) Then
		    Return mCache.Value(cacheKey)
		  End If

		  Var queryEmb As MemoryBlock = FetchEmbedding(query)
		  If queryEmb = Nil Then Return ""

		  // --- Vector search: score all embedded chunks (#12 persistent connection) ---
		  Var rs As RowSet
		  Try
		    rs = mDB.SelectSQL("SELECT c.id, c.title, c.chunk_text, c.source, c.chunk_index, c.prev_id, c.next_id, e.embedding FROM embeddings e JOIN chunks c ON e.chunk_id = c.id")
		  Catch e As DatabaseException
		    Return ""
		  End Try

		  Var chunkIDs() As Integer
		  Var titles() As String
		  Var texts() As String
		  Var sources() As String
		  Var chunkIndexes() As Integer
		  Var prevIDs() As Integer
		  Var nextIDs() As Integer
		  Var scores() As Double

		  Do Until rs.AfterLastRow
		    Var embBlob As MemoryBlock = rs.Column("embedding").BlobValue
		    If embBlob <> Nil And embBlob.Size > 0 Then
		      Var score As Double = CosineSimilarity(queryEmb, embBlob)
		      chunkIDs.Add(rs.Column("id").IntegerValue)
		      titles.Add(rs.Column("title").StringValue)
		      texts.Add(rs.Column("chunk_text").StringValue)
		      sources.Add(rs.Column("source").StringValue)
		      chunkIndexes.Add(rs.Column("chunk_index").IntegerValue)
		      prevIDs.Add(rs.Column("prev_id").IntegerValue)
		      nextIDs.Add(rs.Column("next_id").IntegerValue)
		      scores.Add(score)
		    End If
		    rs.MoveToNextRow
		  Loop
		  rs.Close

		  // --- FTS5 hybrid scoring (#1): boost vector scores with full-text rank ---
		  Var ftsScores() As Double
		  For i As Integer = 0 To chunkIDs.LastIndex
		    ftsScores.Add(0.0)
		  Next i

		  Try
		    Var ftsRS As RowSet = mDB.SelectSQL( _
		      "SELECT rowid, bm25(chunks_fts) AS bm25_score FROM chunks_fts WHERE chunks_fts MATCH ? LIMIT 200", _
		      query)
		    If ftsRS <> Nil Then
		      // Build an ID→fts-score map by scanning results
		      Var ftsMap As New Dictionary
		      Do Until ftsRS.AfterLastRow
		        Var rid As Integer = ftsRS.Column("rowid").IntegerValue
		        // bm25() returns negative values; more negative = better match
		        Var bm25 As Double = ftsRS.Column("bm25_score").DoubleValue
		        // Normalise to [0,1]: map bm25 from (-∞,0] to [0,1] via simple sigmoid-like clamp
		        Var normScore As Double = 1.0 / (1.0 + Exp(bm25 * 0.5))
		        ftsMap.Value(rid) = normScore
		        ftsRS.MoveToNextRow
		      Loop
		      ftsRS.Close
		      // Apply FTS scores to our result array
		      For i As Integer = 0 To chunkIDs.LastIndex
		        If ftsMap.HasKey(chunkIDs(i)) Then
		          ftsScores(i) = CDbl(ftsMap.Value(chunkIDs(i)))
		        End If
		      Next i
		    End If
		  Catch
		    // FTS not available (old DB without chunks_fts) — vector-only mode.
		  End Try

		  // Combine: 70% vector + 30% FTS
		  Var combinedScores() As Double
		  For i As Integer = 0 To scores.LastIndex
		    combinedScores.Add(scores(i) * 0.7 + ftsScores(i) * 0.3)
		  Next i

		  // --- Partial selection sort for top maxResults*2 candidates (to allow dedup) ---
		  Var candidateCount As Integer = maxResults * 2
		  If combinedScores.Count < candidateCount Then candidateCount = combinedScores.Count
		  Var used() As Boolean
		  For i As Integer = 0 To combinedScores.LastIndex
		    used.Add(False)
		  Next i

		  Var topIdxs() As Integer
		  For r As Integer = 0 To candidateCount - 1
		    Var bestIdx As Integer = -1
		    Var bestScore As Double = -2.0
		    For i As Integer = 0 To combinedScores.LastIndex
		      If Not used(i) And combinedScores(i) > bestScore Then
		        bestScore = combinedScores(i)
		        bestIdx = i
		      End If
		    Next i
		    If bestIdx < 0 Then Exit
		    used(bestIdx) = True
		    topIdxs.Add(bestIdx)
		  Next r

		  // --- Deduplication (#4): skip chunks from same source with near-identical score ---
		  // Also tracks which chunk IDs are included so neighbour expansion doesn't re-add them.
		  Var includedIDs As New Dictionary
		  Var sourceLastScore As New Dictionary
		  Var kDedupeScoreDelta As Double = 0.04

		  Var finalIdxs() As Integer
		  For Each idx As Integer In topIdxs
		    If finalIdxs.Count >= maxResults Then Exit
		    Var src As String = sources(idx)
		    Var sc As Double = combinedScores(idx)
		    If sourceLastScore.HasKey(src) Then
		      Var prevScore As Double = CDbl(sourceLastScore.Value(src))
		      // Keep the chunk only if it adds meaningfully different content from the same source.
		      If Abs(sc - prevScore) < kDedupeScoreDelta Then Continue
		    End If
		    sourceLastScore.Value(src) = sc
		    includedIDs.Value(chunkIDs(idx)) = True
		    finalIdxs.Add(idx)
		  Next

		  // --- Neighbour expansion (#6): for high-score chunks, pull adjacent chunks ---
		  Var kNeighbourThreshold As Double = 0.72
		  Var neighbourIdxs() As Integer  // indices into the original arrays for neighbour chunks

		  For Each idx As Integer In finalIdxs
		    If scores(idx) < kNeighbourThreshold Then Continue
		    // Fetch prev chunk if not already included
		    Var pID As Integer = prevIDs(idx)
		    If pID > 0 And Not includedIDs.HasKey(pID) Then
		      Var nChunk As RowSet = FetchChunkByID(pID)
		      If nChunk <> Nil Then
		        includedIDs.Value(pID) = True
		        chunkIDs.Add(pID)
		        titles.Add(nChunk.Column("title").StringValue)
		        texts.Add(nChunk.Column("chunk_text").StringValue)
		        sources.Add(nChunk.Column("source").StringValue)
		        chunkIndexes.Add(nChunk.Column("chunk_index").IntegerValue)
		        prevIDs.Add(nChunk.Column("prev_id").IntegerValue)
		        nextIDs.Add(nChunk.Column("next_id").IntegerValue)
		        nChunk.Close
		        neighbourIdxs.Add(chunkIDs.LastIndex)
		      End If
		    End If
		    // Fetch next chunk if not already included
		    Var nID As Integer = nextIDs(idx)
		    If nID > 0 And Not includedIDs.HasKey(nID) Then
		      Var nChunk As RowSet = FetchChunkByID(nID)
		      If nChunk <> Nil Then
		        includedIDs.Value(nID) = True
		        chunkIDs.Add(nID)
		        titles.Add(nChunk.Column("title").StringValue)
		        texts.Add(nChunk.Column("chunk_text").StringValue)
		        sources.Add(nChunk.Column("source").StringValue)
		        chunkIndexes.Add(nChunk.Column("chunk_index").IntegerValue)
		        prevIDs.Add(nChunk.Column("prev_id").IntegerValue)
		        nextIDs.Add(nChunk.Column("next_id").IntegerValue)
		        nChunk.Close
		        neighbourIdxs.Add(chunkIDs.LastIndex)
		      End If
		    End If
		  Next

		  // --- Logical sorting (#9): group by source, sort groups by best combined score,
		  //     sort chunks within each group by chunk_index ---
		  // Build: source → list of (chunk_index, title, text, isNeighbour)
		  Var sourceOrder() As String          // source names in score order
		  Var sourceSeen As New Dictionary
		  // First pass: add sources from finalIdxs (ordered by combined score)
		  For Each idx As Integer In finalIdxs
		    Var src As String = sources(idx)
		    If Not sourceSeen.HasKey(src) Then
		      sourceSeen.Value(src) = True
		      sourceOrder.Add(src)
		    End If
		  Next
		  // Also add sources from neighbour chunks (they share source with a finalIdx entry,
		  // so they'll already be in sourceOrder — no new sources from neighbours).

		  // Build per-source chunk lists: (chunk_index, arrayIndex)
		  Var sourceChunks As New Dictionary
		  // Populate from finalIdxs
		  For Each idx As Integer In finalIdxs
		    Var src As String = sources(idx)
		    If Not sourceChunks.HasKey(src) Then
		      sourceChunks.Value(src) = New Dictionary
		    End If
		    Var srcMap As Dictionary = sourceChunks.Value(src)
		    srcMap.Value(chunkIndexes(idx)) = idx
		  Next
		  // Populate from neighbourIdxs
		  For Each idx As Integer In neighbourIdxs
		    Var src As String = sources(idx)
		    If Not sourceChunks.HasKey(src) Then
		      sourceChunks.Value(src) = New Dictionary
		    End If
		    Var srcMap As Dictionary = sourceChunks.Value(src)
		    srcMap.Value(chunkIndexes(idx)) = idx
		  Next

		  // Render results
		  Var results() As String
		  For Each src As String In sourceOrder
		    If Not sourceChunks.HasKey(src) Then Continue
		    Var srcMap As Dictionary = sourceChunks.Value(src)
		    // Sort chunk_index values ascending
		    Var idxKeys() As Integer
		    For Each k As Variant In srcMap.Keys
		      idxKeys.Add(k.IntegerValue)
		    Next
		    // Simple insertion sort (small list)
		    For si As Integer = 1 To idxKeys.LastIndex
		      Var key As Integer = idxKeys(si)
		      Var sj As Integer = si - 1
		      While sj >= 0 And idxKeys(sj) > key
		        idxKeys(sj + 1) = idxKeys(sj)
		        sj = sj - 1
		      Wend
		      idxKeys(sj + 1) = key
		    Next si

		    For Each cidx As Integer In idxKeys
		      Var ai As Integer = srcMap.Value(cidx)
		      results.Add("--- " + titles(ai) + " ---" + EndOfLine + texts(ai))
		    Next
		  Next

		  If results.Count = 0 Then Return ""

		  Var output As String = "Found " + results.Count.ToString + " result(s) for """ + query + """ (semantic):" + _
		    EndOfLine + EndOfLine + String.FromArray(results, EndOfLine + EndOfLine)

		  // Store in cache (#13)
		  If mCache = Nil Then mCache = New Dictionary
		  If mCache.Count >= kCacheMaxEntries Then
		    // Simple eviction: clear the whole cache when full.
		    mCache = New Dictionary
		  End If
		  mCache.Value(cacheKey) = output

		  Return output

		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function FetchChunkByID(id As Integer) As RowSet
		  If mDB = Nil Then Return Nil
		  Try
		    Var rs As RowSet = mDB.SelectSQL( _
		      "SELECT title, chunk_text, source, chunk_index, prev_id, next_id FROM chunks WHERE id = ?", id)
		    If rs = Nil Or rs.AfterLastRow Then Return Nil
		    Return rs
		  Catch e As DatabaseException
		    Return Nil
		  End Try
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function FetchEmbedding(text As String) As MemoryBlock
		  Var escapedText As String = EscapeJSON(text)
		  Var body As String = "{""model"":""nomic-embed-text.gguf"",""input"":""" + escapedText + """}"

		  mHttpDone = False
		  mHttpBody = ""
		  mHttpStatus = 0

		  Var http As New URLConnection
		  AddHandler http.ContentReceived, AddressOf HttpContentReceived
		  http.RequestHeader("Content-Type") = "application/json"
		  http.SetRequestContent(body, "application/json")

		  Try
		    http.Send("POST", mEmbeddingUrl)
		  Catch e As RuntimeException
		    Return Nil
		  End Try

		  Var timeout As Integer = 0
		  While Not mHttpDone And timeout < 10000
		    App.DoEvents(10)
		    timeout = timeout + 10
		  Wend

		  If Not mHttpDone Or mHttpStatus <> 200 Then Return Nil

		  Return ParseEmbeddingJSON(mHttpBody)

		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub HttpContentReceived(sender As URLConnection, url As String, httpStatus As Integer, content As String)
		  #Pragma Unused sender
		  #Pragma Unused url
		  mHttpStatus = httpStatus
		  mHttpBody = content.DefineEncoding(Encodings.UTF8)
		  mHttpDone = True

		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function ParseEmbeddingJSON(json As String) As MemoryBlock
		  Var root As JSONItem
		  Try
		    root = New JSONItem(json)
		  Catch e As JSONException
		    Return Nil
		  End Try

		  If Not root.HasKey("data") Then Return Nil
		  Var dataArr As JSONItem = root.Child("data")
		  If dataArr = Nil Or dataArr.Count = 0 Then Return Nil
		  Var firstItem As JSONItem = dataArr.ChildAt(0)
		  If Not firstItem.HasKey("embedding") Then Return Nil
		  Var embArr As JSONItem = firstItem.Child("embedding")
		  Var floatCount As Integer = embArr.Count
		  If floatCount = 0 Then Return Nil

		  Var mb As New MemoryBlock(floatCount * 4)
		  mb.LittleEndian = True
		  For i As Integer = 0 To floatCount - 1
		    mb.SingleValue(i * 4) = CDbl(embArr.ValueAt(i))
		  Next i

		  Return mb

		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function CosineSimilarity(a As MemoryBlock, b As MemoryBlock) As Double
		  If a = Nil Or b = Nil Then Return 0
		  Var count As Integer = a.Size / 4
		  If b.Size / 4 < count Then count = b.Size / 4

		  Var dot As Double = 0
		  Var na As Double = 0
		  Var nb As Double = 0
		  For i As Integer = 0 To count - 1
		    Var ai As Double = a.SingleValue(i * 4)
		    Var bi As Double = b.SingleValue(i * 4)
		    dot = dot + ai * bi
		    na = na + ai * ai
		    nb = nb + bi * bi
		  Next i

		  If na = 0 Or nb = 0 Then Return 0
		  Return dot / (Sqrt(na) * Sqrt(nb))

		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function EscapeJSON(s As String) As String
		  Var result As String = s
		  result = result.ReplaceAll("\", "\\")
		  result = result.ReplaceAll("""", "\""")
		  result = result.ReplaceAll(Chr(8), "\b")
		  result = result.ReplaceAll(Chr(9), "\t")
		  result = result.ReplaceAll(Chr(10), "\n")
		  result = result.ReplaceAll(Chr(12), "\f")
		  result = result.ReplaceAll(Chr(13), "\r")
		  Return result

		End Function
	#tag EndMethod


	#tag Property, Flags = &h21
		Private mAvailable As Boolean
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mEmbeddingUrl As String
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mDbPath As String
	#tag EndProperty

	// Persistent connection held open for the process lifetime (#12).
	#tag Property, Flags = &h21
		Private mDB As SQLiteDatabase
	#tag EndProperty

	// In-memory query cache: cacheKey → result string (#13).
	#tag Property, Flags = &h21
		Private mCache As Dictionary
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mHttpDone As Boolean
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mHttpBody As String
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mHttpStatus As Integer
	#tag EndProperty

	// Maximum number of cached query results before the cache is cleared.
	#tag Constant, Name = kCacheMaxEntries, Type = Integer, Dynamic = False, Default = \"50", Scope = Private
	#tag EndConstant

	// Cosine score threshold above which neighbour chunks are fetched (#6).
	#tag Constant, Name = kNeighbourThreshold, Type = Double, Dynamic = False, Default = \"0.72", Scope = Private
	#tag EndConstant


	#tag ViewBehavior
		#tag ViewProperty
			Name="Name"
			Visible=true
			Group="ID"
			InitialValue=""
			Type="String"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Index"
			Visible=true
			Group="ID"
			InitialValue="-2147483648"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Super"
			Visible=true
			Group="ID"
			InitialValue=""
			Type="String"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Left"
			Visible=true
			Group="Position"
			InitialValue="0"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
		#tag ViewProperty
			Name="Top"
			Visible=true
			Group="Position"
			InitialValue="0"
			Type="Integer"
			EditorType=""
		#tag EndViewProperty
	#tag EndViewBehavior
End Class
#tag EndClass
