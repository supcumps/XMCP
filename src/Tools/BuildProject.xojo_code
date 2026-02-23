#tag Class
Protected Class BuildProject
Inherits MCPKit.Tool
	#tag Method, Flags = &h0
		Sub Constructor()
		  Super.Constructor("build_project", "Builds the current Xojo project. Returns the path to the built application on success, or build errors on failure.")

		  Parameters.Add(New MCPKit.ToolParameter("build_type", MCPKit.ToolParameterTypes.Integer_, _
		  "Build type: 0=Default, 5=macOS (Cocoa), 9=Windows 32-bit, 14=Windows 64-bit, 16=Linux 32-bit, 17=Linux 64-bit, 18=Linux ARM, 24=macOS Universal. Default is 0.", _
		  True, 0, False))

		  Parameters.Add(New MCPKit.ToolParameter("reveal", MCPKit.ToolParameterTypes.Boolean_, _
		  "Whether to reveal the built app in Finder/Explorer after building. Default is false.", _
		  True, False, False))

		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function Run(args() As MCPKit.ToolArgument) As MCPKit.ToolResult
		  Var buildType As Integer = 0
		  Var reveal As Boolean = False
		  For Each arg As MCPKit.ToolArgument In args
		    If arg.Name = "build_type" Then
		      buildType = arg.Value.IntegerValue
		    ElseIf arg.Name = "reveal" Then
		      reveal = arg.Value.BooleanValue
		    End If
		  Next arg

		  // DoCommand "BuildApp" returns a buildError JSON object on failure,
		  // or {} on success. The IDE returns it directly as the response value —
		  // not via Print — so we just call DoCommand and let the response come back.
		  Var revealStr As String = If(reveal, "True", "False")
		  Var script As String = _
		  "DoCommand ""BuildApp " + buildType.ToString + " " + revealStr + """" + EndOfLine + _
		  "Print """""

		  // Builds can take a long time — use a 120 second timeout.
		  If App.IDE = Nil Then
		    Return MCPKit.ToolResult.Failure("Xojo IDE is not connected. Start the IDE and restart XMCP.")
		  End If

		  Var response As JSONItem = App.IDE.SendAndReceive(script, 120000)
		  If response = Nil Then
		    If App.IDE.LastErrorMessage <> "" Then
		      Return MCPKit.ToolResult.Failure(App.IDE.LastErrorMessage)
		    End If
		    Return MCPKit.ToolResult.Failure("Timeout waiting for build to complete (120s).")
		  End If

		  If response.HasKey("response") Then
		    Var resp As Variant = response.Value("response")

		    // DoCommand returns a JSON string we printed — parse it.
		    If resp.Type = Variant.TypeString Then
		      Var respStr As String = resp.StringValue
		      Try
		        Var resultJSON As New JSONItem(respStr)
		        Return ParseDoCommandResult(resultJSON)
		      Catch e As JSONException
		        // Not JSON — treat as a plain success message.
		        Return MCPKit.ToolResult.Success("Build succeeded: " + respStr)
		      End Try
		    Else
		      // Already a JSON object in the response envelope.
		      Var respJSON As JSONItem = response.Value("response")
		      Return ParseDoCommandResult(respJSON)
		    End If
		  End If

		  Return MCPKit.ToolResult.Failure("Unexpected response from IDE: " + response.ToString)

		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function ParseDoCommandResult(resultJSON As JSONItem) As MCPKit.ToolResult
		  /// Parses the JSON returned by DoCommand "BuildApp".
		  /// Success: empty {} → "Build succeeded."
		  /// Failure: {"buildError": {"errors": [...]}} → formatted error list.

		  If resultJSON.Count = 0 Then
		    Return MCPKit.ToolResult.Success("Build succeeded.")
		  End If

		  If resultJSON.HasKey("buildError") Then
		    Var buildError As JSONItem = resultJSON.Value("buildError")
		    If buildError.HasKey("errors") Then
		      Var errors As JSONItem = buildError.Value("errors")
		      Var lines() As String
		      Var i As Integer
		      For i = 0 To errors.Count - 1
		        Var err As JSONItem = errors.Value(i)
		        Var errType As String = If(err.HasKey("type"), err.Value("type").StringValue, "Error")
		        Var msg As String = If(err.HasKey("message"), err.Value("message").StringValue, "")
		        Var location As String = If(err.HasKey("location"), err.Value("location").StringValue, "")
		        Var position As String = If(err.HasKey("position"), err.Value("position").StringValue, "")
		        Var line As String = errType + ": " + msg
		        If location <> "" Then line = line + " [" + location + "]"
		        If position <> "" And position <> location Then line = line + " (" + position + ")"
		        lines.Add(line)
		      Next i
		      Return MCPKit.ToolResult.Failure("Build errors (" + errors.Count.ToString + "):" + EndOfLine + String.FromArray(lines, EndOfLine))
		    End If
		    Return MCPKit.ToolResult.Failure("Build failed: " + buildError.ToString)
		  End If

		  // Unknown JSON structure — return raw for debugging.
		  Return MCPKit.ToolResult.Failure("Build failed: " + resultJSON.ToString)

		End Function
	#tag EndMethod


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
		#tag ViewProperty
			Name="Description"
			Visible=false
			Group="Behavior"
			InitialValue=""
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
	#tag EndViewBehavior
End Class
#tag EndClass
