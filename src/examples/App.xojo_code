#tag Class
Protected Class App
Inherits Application
	#tag Event
		Sub Opening()
		  // App startup code here
		End Sub
	#tag EndEvent

	#tag Event
		Sub UnhandledException(error As RuntimeException)
		  Var msg As String = "Error: " + error.Message + EndOfLine
		  msg = msg + "Error Number: " + Str(error.ErrorNumber) + EndOfLine
		  If error.Stack <> Nil Then
		    msg = msg + "Stack:" + EndOfLine
		    For Each frame As String In error.Stack
		      msg = msg + "  " + frame + EndOfLine
		    Next
		  End If

		  Var f As New FolderItem("/tmp/xmcp_debug.log")
		  Var stream As TextOutputStream = TextOutputStream.Open(f)
		  stream.Write(msg)
		  stream.Close
		End Sub
	#tag EndEvent

	#tag Method, Flags = &h0
		Sub MyMethod()
		  // Method on App
		End Sub
	#tag EndMethod

	#tag Property, Flags = &h0
		MyProperty As String
	#tag EndProperty

	#tag Constant, Flags = &h0
		kAppName As String = "MyApp"
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
	#tag EndViewBehavior
End Class
#tag EndClass
