#tag Class
Protected Class SelectProjectItem
Inherits MCPKit.Tool
	#tag Method, Flags = &h0
		Sub Constructor()
		  Super.Constructor("select_project_item", "Selects and navigates to a specific item in the Xojo IDE Navigator. Use dot-separated paths like 'Module1.MyMethod'.")

		  Parameters.Add(New MCPKit.ToolParameter("item_path", MCPKit.ToolParameterTypes.String_, _
		  "Dot-separated path to the project item to select (e.g. 'App', 'Module1.MyMethod').", _
		  False, "", True))

		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function Run(args() As MCPKit.ToolArgument) As MCPKit.ToolResult
		  Var itemPath As String = ""
		  For Each arg As MCPKit.ToolArgument In args
		    If arg.Name = "item_path" Then
		      itemPath = arg.Value.StringValue
		      Exit
		    End If
		  Next arg

		  If itemPath = "" Then
		    Return MCPKit.ToolResult.Failure("The item_path parameter is required.")
		  End If

		  Var script As String = "Dim result As Boolean = SelectProjectItem(""" + _
		  itemPath.ReplaceAll("""", """""") + """)" + EndOfLine + _
		  "If result Then" + EndOfLine + _
		  "  Print ""Selected: "" + Location + "" ("" + TypeOfCurrentLocation + "")""" + EndOfLine + _
		  "Else" + EndOfLine + _
		  "  Print ""ERROR: Could not select '" + itemPath.ReplaceAll("""", """""") + "'. The IDE scripting API cannot navigate to method-level items or event handlers. Edit the source file directly on disk instead.""" + EndOfLine + _
		  "End If"

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
