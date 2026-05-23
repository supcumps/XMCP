#tag Class
Protected Class RevertProject
Inherits MCPKit.Tool
	#tag Method, Flags = &h0
		Sub Constructor()
		  Super.Constructor("revert_project", "Reloads the current Xojo project from disk so that on-disk edits to .xojo_code / .xojo_window / .xojo_project files are picked up by the IDE. By default, the IDE's in-memory project is saved to disk first so no in-IDE work is lost. Pass force=true to skip the save and discard any unsaved IDE edits.")

		  Parameters.Add(New MCPKit.ToolParameter("force", MCPKit.ToolParameterTypes.Boolean_, _
		  "If true, skip saving the IDE's in-memory project before reloading and discard any unsaved IDE edits. Default is false (save first, then reload — safe).", _
		  True, False, False))

		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function Run(args() As MCPKit.ToolArgument) As MCPKit.ToolResult
		  Var force As Boolean = False
		  For Each arg As MCPKit.ToolArgument In args
		    If arg.Name = "force" Then force = arg.Value.BooleanValue
		  Next

		  If App.IDE = Nil Then
		    Return MCPKit.ToolResult.Failure("Xojo IDE is not connected. Start the IDE and restart XMCP.")
		  End If

		  // DoCommand("RevertFile") shows a confirmation dialog that blocks the script,
		  // so we close and reopen the project manually. When force=False (default), we
		  // save the IDE's in-memory state first so no unsaved work is lost — the user's
		  // edits are merged onto disk before we reload from disk.
		  Var script As String
		  If force Then
		    script = _
		    "Dim path As String = ProjectShellPath" + EndOfLine + _
		    "CloseProject(False)" + EndOfLine + _
		    "OpenFile path" + EndOfLine + _
		    "Print ""Project reloaded from disk (force=true; any unsaved IDE edits discarded)."""
		  Else
		    script = _
		    "Dim path As String = ProjectShellPath" + EndOfLine + _
		    "DoCommand ""SaveProject""" + EndOfLine + _
		    "CloseProject(False)" + EndOfLine + _
		    "OpenFile path" + EndOfLine + _
		    "Print ""Project saved and reloaded from disk."""
		  End If

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
