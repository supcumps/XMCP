#tag Class
Protected Class MyClass
Inherits Object
	#tag Method, Flags = &h0
		Sub Constructor(name As String)
		  mName = name
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function Greet() As String
		  Return "Hello from " + mName
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub InternalHelper()
		  // Private — not visible to callers
		End Sub
	#tag EndMethod

	#tag Property, Flags = &h0
		MyProperty As Integer
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mName As String
	#tag EndProperty

	#tag Constant, Flags = &h0
		kMaxItems As Integer = 100
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
