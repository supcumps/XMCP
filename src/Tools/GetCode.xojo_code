#tag Class
Protected Class GetCode
Inherits MCPKit.Tool
	#tag Method, Flags = &h0
		Sub Constructor()
		  Super.Constructor("get_code", "Reads the source code at the current or specified location in the Xojo IDE. Navigate to the desired location first using select_project_item if needed.")

		  Parameters.Add(New MCPKit.ToolParameter("location", MCPKit.ToolParameterTypes.String_, _
		  "Optional dot-separated path to navigate to before reading code. If empty, reads from current location.", _
		  True, "", False))

		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function Run(args() As MCPKit.ToolArgument) As MCPKit.ToolResult
		  Var location As String = ""
		  For Each arg As MCPKit.ToolArgument In args
		    If arg.Name = "location" Then
		      location = arg.Value.StringValue
		      Exit
		    End If
		  Next arg

		  Var script As String = ""

		  If location <> "" Then
		    script = "Dim result As Boolean = SelectProjectItem(""" + _
		    location.ReplaceAll("""", """""") + """)" + EndOfLine + _
		    "If Not result Then" + EndOfLine + _
		    "  Print ""ERROR: Could not navigate to: " + location.ReplaceAll("""", """""") + ". For window event handlers, edit the .xojo_window file directly on disk and call revert_project.""" + EndOfLine + _
		    "Else" + EndOfLine + _
		    "  Try" + EndOfLine + _
		    "    Print Text" + EndOfLine + _
		    "  Catch" + EndOfLine + _
		    "    Print ""ERROR: No code editor is active. Navigate to a method or property first, or use get_project_info to find the project directory and edit the .xojo_code file directly, then call revert_project.""" + EndOfLine + _
		    "  End Try" + EndOfLine + _
		    "End If"
		  Else
		    script = _
		    "Try" + EndOfLine + _
		    "  Print Text" + EndOfLine + _
		    "Catch" + EndOfLine + _
		    "  Print ""ERROR: No code editor is active. Navigate to a method or property first, or use get_project_info to find the project directory and edit the .xojo_code file directly, then call revert_project.""" + EndOfLine + _
		    "End Try"
		  End If

		  If App.IDE = Nil Then
		    Return MCPKit.ToolResult.Failure("Xojo IDE is not connected. Start the IDE and restart XMCP.")
		  End If
		  
		  Return App.IDE.RunScript(script)

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
