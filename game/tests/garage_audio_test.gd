extends SceneTree
## v0.1.12 regression: VAZ-2106 real dimensions, matching visual vs driving
## wheelbase, garage red/white variants, audio event pipeline.
const CAR = preload("res://scripts/vehicles/lada_lowpoly.gd")
const DRIVE = preload("res://scripts/driving/drive_model.gd")
const AUDIO = preload("res://scripts/audio/drive_audio.gd")
const GARAGE = preload("res://scenes/garage.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    if absf(CAR.BODY_LENGTH_M-4.166) > 0.001:
        _fail("Lada body length must equal 4.166m")
        return
    if absf(CAR.WHEELBASE_M-2.424) > 0.001 or absf(DRIVE.WHEELBASE-2.424)>0.001:
        _fail("Driving and visual wheelbase must equal 2.424m")
        return
    for variant in ["red","white"]:
        var car: NitroLadaLowPoly = CAR.new()
        car.paint_variant = variant
        root.add_child(car)
        await process_frame
        if car.rolling_wheels.size()!=4 or car.front_wheels.size()!=2:
            _fail("Four wheels and two front steering pivots required")
            return
        var z: Array[float] = []
        for pivot in car.front_wheels:
            z.append(pivot.position.z)
        if absf(z[0]-CAR.FRONT_AXLE_Z)>0.0001:
            _fail("Front wheel at wrong visual X/Z")
            return
        var found_rear: bool = false
        for wheel in car.rolling_wheels:
            if absf(wheel.get_parent().position.z-CAR.REAR_AXLE_Z)<0.0001:
                found_rear = true
        if not found_rear:
            _fail("Rear axle missing")
            return
        var hood: Node = car.find_child("White variant closed long bonnet",true,false)
        if (variant=="white") != (hood!=null):
            _fail("White closed bonnet variant did not differ from red engine bay")
            return
        if car.find_child("Long rear boot lid",true,false)==null:
            _fail("Long boot panel missing")
            return
        car.queue_free()
        await process_frame

    var garage: Control = GARAGE.instantiate()
    root.add_child(garage)
    await process_frame
    if garage.get("car")==null:
        _fail("Garage preview did not initialize")
        return
    garage.call("_choose_white")
    if garage.get("active_variant") != "white":
        _fail("Garage cannot select white")
        return
    if ProjectSettings.get_setting("nitro/car_variant","") != "white":
        _fail("White variant not persisted for race")
        return
    garage.call("_choose_red")
    if garage.get("active_variant")!="red":
        _fail("Garage cannot return to red")
        return
    garage.queue_free()
    await process_frame

    var sound: NitroDriveAudio = AUDIO.new()
    root.add_child(sound)
    await process_frame
    if sound.CLIPS.size()!=17:
        _fail("Audio registry must expose 17 named user recordings")
        return
    # Loading 17 live decoders in a headless server can falsely leak streams
    # at engine shutdown. Import presence is checked here; device playback
    # is a separate handset QA requirement.
    for name in sound.CLIPS:
        var uri: String = "res://assets/audio/"+name+".ogg"
        if not ResourceLoader.exists(uri):
            _fail("Missing Git-tracked OGG asset: "+uri)
            return
    if DisplayServer.get_name() != "headless":
        if not sound.has_source_audio or sound.voices.size()!=17:
            _fail("Actual display build did not attach 17 imported OGG streams")
            return
    # Partial asset import must never crash the game or cover controls.
    sound.drive_tick(65.0,35.0,1.0,1.0,false,1.0/120.0)
    sound.wall_event(8.0)
    sound.kerb_event(65.0)
    sound.silence()
    sound.queue_free()
    print("PASS: 4.166m/2.424m Lada, red/white garage, 17 source OGG assets found and wired")
    print("NOT RUN: headless sound decoding/playback and physical Android speaker/steering feel")
    quit(0)

func _fail(msg: String) -> void:
    printerr("FAIL: "+msg)
    quit(1)
