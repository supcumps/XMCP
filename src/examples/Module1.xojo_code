#tag Module
Protected Module Module1
	#tag Method, Flags = &h0
		Function FormatGreeting(name As String) As String
		  // Public module method — called as Module1.FormatGreeting("Alice")
		  // or just FormatGreeting("Alice") from within the same scope.
		  Return "Hello, " + name + "!"
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub HelperMethod()
		  // Private — not visible outside this module
		End Sub
	#tag EndMethod

	#tag Constant, Flags = &h0
		kVersion As String = "1.0.0"
	#tag EndConstant

	#tag Property, Flags = &h0
		SharedState As String
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mCachedValue As String
	#tag EndProperty

	#tag Note, Name = DesignNotes
		Module1 demonstrates the standard block layout for a Xojo module file.

		Key differences from a class file:
		  - No #tag Event blocks (modules cannot define or raise events)
		  - No Constructor
		  - All methods and properties are implicitly Shared (module-level)
		  - No "Shared " keyword needed — it is implied

		Block ordering within a .xojo_code module file (must be preserved exactly):
		  1. #tag Method blocks
		  2. #tag Constant blocks
		  3. #tag Property blocks
		  4. #tag Note blocks
		  5. #tag ViewBehavior  (always last)

		Access modifier flags:
		  &h0   Public
		  &h1   Protected  (rarely used in modules — visible within the namespace)
		  &h21  Private

		Modules defined inside another module (namespace modules) use the same
		file format. The .xojo_project entry uses "Module=Name;Path" for top-level
		and "Module=Name;SubPath;ParentID" for nested modules.
	#tag EndNote

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
