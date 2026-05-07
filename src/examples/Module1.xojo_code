#tag Module
Protected Module Module1
	#tag Method, Flags = &h0
		Function FormatGreeting(name As String) As String
		  Return "Hello, " + name + "!"
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub HelperMethod()
		  // Private helper — not visible outside module
		End Sub
	#tag EndMethod

	#tag Constant, Flags = &h0
		kVersion As String = "1.0.0"
	#tag EndConstant

	#tag Property, Flags = &h0
		SharedState As String
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
	#tag EndViewBehavior
End Module
#tag EndModule
