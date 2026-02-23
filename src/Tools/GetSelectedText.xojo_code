#tag Class
Protected Class GetSelectedText
Inherits MCPKit.Tool
	#tag Method, Flags = &h0
		Sub Constructor()
		  Super.Constructor("get_selected_text", "Returns the currently selected text in the Xojo IDE code editor, along with the selection start position and length.")

		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function Run(args() As MCPKit.ToolArgument) As MCPKit.ToolResult
		  #Pragma Unused args

		  Var script As String = _
		  "Try" + EndOfLine + _
		  "  Dim s As String = SelectedText" + EndOfLine + _
		  "  Dim ss As Integer = SelectionStart" + EndOfLine + _
		  "  Dim sl As Integer = SelectionLength" + EndOfLine + _
		  "  Print ""start="" + Str(ss) + "" length="" + Str(sl) + Chr(10) + s" + EndOfLine + _
		  "Catch" + EndOfLine + _
		  "  Print ""ERROR: No code editor is active. Navigate to a method or property first.""" + EndOfLine + _
		  "End Try"

		  If App.IDE = Nil Then
		    Return MCPKit.ToolResult.Failure("Xojo IDE is not connected. Start the IDE and restart XMCP.")
		  End If

		  Var response As JSONItem = App.IDE.SendAndReceive(script)
		  If response = Nil Then
		    If App.IDE.LastErrorMessage <> "" Then
		      Return MCPKit.ToolResult.Failure(App.IDE.LastErrorMessage)
		    End If
		    Return MCPKit.ToolResult.Failure("Timeout waiting for IDE response.")
		  End If

		  If response.HasKey("response") Then
		    Var resp As Variant = response.Value("response")
		    If resp.Type = Variant.TypeString Then
		      Var respStr As String = resp.StringValue
		      If respStr.BeginsWith("ERROR:") Then
		        Return MCPKit.ToolResult.Failure(respStr)
		      End If
		      Return MCPKit.ToolResult.Success(respStr)
		    Else
		      Var respJSON As JSONItem = response.Value("response")
		      Return MCPKit.ToolResult.Success(respJSON.ToString)
		    End If
		  End If

		  Return MCPKit.ToolResult.Failure("Unexpected response from IDE: " + response.ToString)

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
