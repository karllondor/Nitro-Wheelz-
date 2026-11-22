# Renders game/assets/brand/nitro_wheelz_logo.svg to a PNG (the owner-approved full logo, unchanged):
#   OUT=/abs/logo_render.png [SCALE=1.8] godot --headless --path game --script ../tools/art/render_logo_svg.gd
# SCALE 1.8 = 1116 x 628 (input of make_track_textures.py); SCALE 2.4 = 1488 x 838 is
# game/assets/brand/nitro_wheelz_logo_pavement.png, the decal at the centre of NITRO WHEELZ PARK
# (issue #27). tools for the art pipeline; not part of the game.
extends SceneTree
func _initialize() -> void:
    var txt: String = FileAccess.get_file_as_string("res://assets/brand/nitro_wheelz_logo.svg")
    var img := Image.new()
    var scale: float = float(OS.get_environment("SCALE")) if OS.get_environment("SCALE") != "" else 1.8
    var err: int = img.load_svg_from_string(txt,scale)
    print("err ",err," size ",img.get_size())
    img.save_png(OS.get_environment("OUT"))
    quit(0)
