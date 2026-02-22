#tag Class
Protected Class RunIDEScript
Inherits MCPKit.Tool
	#tag Method, Flags = &h0
		Sub Constructor()
		  Super.Constructor("run_ide_script", "Executes an arbitrary Xojo IDE script. Use Print to return values. This is an escape hatch for any IDE scripting command not covered by other tools.")

		  Parameters.Add(New MCPKit.ToolParameter("script", MCPKit.ToolParameterTypes.String_, _
		  "The IDE script code to execute. Use XojoScript syntax with IDE scripting commands. " + _
		  "Use Print to return output values.", _
		  False, "", True))

		  Parameters.Add(New MCPKit.ToolParameter("timeout", MCPKit.ToolParameterTypes.Integer_, _
		  "Timeout in milliseconds to wait for a response. Default is 10000 (10 seconds).", _
		  True, 10000, False))

		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function Run(args() As MCPKit.ToolArgument) As MCPKit.ToolResult
		  Var script As String = ""
		  Var timeoutMS As Integer = 10000
		  For Each arg As MCPKit.ToolArgument In args
		    If arg.Name = "script" Then
		      script = arg.Value.StringValue
		    ElseIf arg.Name = "timeout" Then
		      timeoutMS = arg.Value.IntegerValue
		    End If
		  Next arg

		  If script = "" Then
		    Return MCPKit.ToolResult.Failure("The script parameter is required.")
		  End If

		  If App.IDE = Nil Then
		    Return MCPKit.ToolResult.Failure("Xojo IDE is not connected. Start the IDE and restart XMCP.")
		  End If
		  
		  Var response As JSONItem = App.IDE.SendAndReceive(script, timeoutMS)
		  If response = Nil Then
		    If App.IDE.LastErrorMessage <> "" Then
		      Return MCPKit.ToolResult.Failure(App.IDE.LastErrorMessage)
		    End If
		    Return MCPKit.ToolResult.Failure("Timeout waiting for IDE response (" + timeoutMS.ToString + "ms).")
		  End If

		  // Check for script errors.
		  If response.HasKey("response") Then
		    Var resp As Variant = response.Value("response")
		    If resp.Type = Variant.TypeString Then
		      Return MCPKit.ToolResult.Success(resp.StringValue)
		    Else
		      // Could be a scriptError object.
		      Var respJSON As JSONItem = response.Value("response")
		      If respJSON.HasKey("scriptError") Then
		        Return MCPKit.ToolResult.Failure("Script error: " + respJSON.ToString)
		      End If
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
