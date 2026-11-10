class_name CreditsData
extends Resource

@export var game_logo: Texture2D
@export var game_title: String = ""
@export var sections: Array[CreditsSection] = []
@export_multiline var closing_text: String = "Thanks for playing!"
