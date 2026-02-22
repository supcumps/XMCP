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

		  Var revealStr As String = If(reveal, "True", "False")
		  Var script As String = "Print BuildApp(" + buildType.ToString + ", " + revealStr + ")"

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

		  // Check for build errors.
		  If response.HasKey("response") Then
		    Var resp As Variant = response.Value("response")

		    // Build errors come as a JSON object, not a string.
		    If resp.Type = Variant.TypeString Then
		      Var respStr As String = resp.StringValue
		      If respStr = "" Then
		        Return MCPKit.ToolResult.Failure("Build failed with no output. Check the IDE for errors.")
		      End If
		      Return MCPKit.ToolResult.Success("Build succeeded: " + respStr)
		    Else
		      // It's a JSON object — either build errors or an empty {} meaning success.
		      Var respJSON As JSONItem = response.Value("response")
		      If respJSON.Count = 0 Then
		        Return MCPKit.ToolResult.Success("Build succeeded.")
		      End If
		      Return MCPKit.ToolResult.Failure("Build errors: " + respJSON.ToString)
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
