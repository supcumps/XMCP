#tag Class
Protected Class RevertProject
Inherits MCPKit.Tool
	#tag Method, Flags = &h0
		Sub Constructor()
		  Super.Constructor("revert_project", "Reloads the current Xojo project from disk so that on-disk edits to .xojo_code / .xojo_window / .xojo_project files are picked up by the IDE. DESTRUCTIVE: any unsaved IDE-side edits are discarded — confirm with the user before calling.")

		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function Run(args() As MCPKit.ToolArgument) As MCPKit.ToolResult
		  #Pragma Unused args

		  If App.IDE = Nil Then
		    Return MCPKit.ToolResult.Failure("Xojo IDE is not connected. Start the IDE and restart XMCP.")
		  End If

		  // DoCommand("RevertFile") shows a confirmation dialog that blocks the script,
		  // so we close and reopen the project manually. CloseProject(False) discards
		  // unsaved IDE edits without prompting — this is intentional: the caller's job
		  // is to ingest disk-side changes, and saving first would overwrite them.
		  Var script As String = _
		  "Dim path As String = ProjectShellPath" + EndOfLine + _
		  "CloseProject(False)" + EndOfLine + _
		  "OpenFile path" + EndOfLine + _
		  "Print ""Project reloaded from disk."""

		  Return App.IDE.RunScript(script, 15000)

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
