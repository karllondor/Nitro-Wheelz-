# Renders game/assets/brand/nitro_wheelz_logo.svg to a PNG (scale 1.8 = 1116 x 628):
#   OUT=/abs/logo_render.png godot --headless --path game --script ../tools/art/render_logo_svg.gd
# (tools for make_track_textures.py; not part of the game)
extends SceneTree
func _initialize() -> void:
    var txt: String = FileAccess.get_file_as_string("res://assets/brand/nitro_wheelz_logo.svg")
    var img := Image.new()
    var err: int = img.load_svg_from_string(txt,1.8)
    print("err ",err," size ",img.get_size())
    img.save_png(OS.get_environment("OUT"))
    quit(0)
