#tag Class
Protected Class SemanticSearch
	#tag Method, Flags = &h0
		Sub Constructor(embeddingUrl As String, dbPath As String)
		  mEmbeddingUrl = embeddingUrl
		  mDbPath = dbPath
		  mAvailable = False

		  Var dbFile As New FolderItem(dbPath, FolderItem.PathModes.Native)
		  If dbFile = Nil Or Not dbFile.Exists Then Return

		  Var db As New SQLiteDatabase
		  db.DatabaseFile = dbFile
		  Try
		    db.Connect
		    db.Close
		  Catch e As DatabaseException
		    Return
		  End Try

		  // Probe the embedding server.
		  Var testEmb As MemoryBlock = FetchEmbedding("test")
		  If testEmb = Nil Then Return

		  mAvailable = True

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

		  Var queryEmb As MemoryBlock = FetchEmbedding(query)
		  If queryEmb = Nil Then Return ""

		  Var dbFile As New FolderItem(mDbPath, FolderItem.PathModes.Native)
		  Var db As New SQLiteDatabase
		  db.DatabaseFile = dbFile
		  Try
		    db.Connect
		  Catch e As DatabaseException
		    Return ""
		  End Try

		  Var rs As RowSet
		  Try
		    rs = db.SelectSQL("SELECT c.title, c.chunk_text, e.embedding FROM embeddings e JOIN chunks c ON e.chunk_id = c.id")
		  Catch e As DatabaseException
		    db.Close
		    Return ""
		  End Try

		  Var titles() As String
		  Var texts() As String
		  Var scores() As Double

		  Do Until rs.AfterLastRow
		    Var embBlob As MemoryBlock = rs.Column("embedding").BlobValue
		    If embBlob <> Nil And embBlob.Size > 0 Then
		      Var score As Double = CosineSimilarity(queryEmb, embBlob)
		      titles.Add(rs.Column("title").StringValue)
		      texts.Add(rs.Column("chunk_text").StringValue)
		      scores.Add(score)
		    End If
		    rs.MoveToNextRow
		  Loop
		  rs.Close
		  db.Close

		  // Partial selection sort for top maxResults.
		  Var limit As Integer = maxResults
		  If scores.Count < limit Then limit = scores.Count
		  Var used() As Boolean
		  Var i As Integer
		  For i = 0 To scores.LastIndex
		    used.Add(False)
		  Next i

		  Var results() As String
		  Var r As Integer
		  For r = 0 To limit - 1
		    Var bestIdx As Integer = -1
		    Var bestScore As Double = -2.0
		    For i = 0 To scores.LastIndex
		      If Not used(i) And scores(i) > bestScore Then
		        bestScore = scores(i)
		        bestIdx = i
		      End If
		    Next i
		    If bestIdx < 0 Then Exit
		    used(bestIdx) = True
		    results.Add("--- " + titles(bestIdx) + " ---" + EndOfLine + texts(bestIdx))
		  Next r

		  If results.Count = 0 Then Return ""

		  Return "Found " + results.Count.ToString + " result(s) for """ + query + """ (semantic):" + _
		    EndOfLine + EndOfLine + String.FromArray(results, EndOfLine + EndOfLine)

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

	#tag Property, Flags = &h21
		Private mHttpDone As Boolean
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mHttpBody As String
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mHttpStatus As Integer
	#tag EndProperty


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
