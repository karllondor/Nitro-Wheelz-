extends "res://tests/net_park_peer.gd"
## Two actual game processes. Only lobby controls, initial approach poses and throttle
## velocity are scripted. Contact, mounts, debris and repair use ordinary game code.
func _run() -> void:
    var args := OS.get_cmdline_user_args()
    host = args[0]=="host"
    driver = args[1]
    port = args[2]
    sync_dir = args[3]
    var enabled := args[4]=="damage"
    CARS.select("white")
    change_scene_to_file(LOBBY)
    if not await _until(_lobby,"LAN menu"): return
    if host:
        current_scene.host_game(P.PARK_PATH,int(port))
        room = current_scene.session
        _mark("listen")
    else:
        if not await _until(func(): return _marked("listen"),"listen"): return
        _connect_ui()
    if not await _until(func(): return room.state==S.State.LOBBY,"lobby"): return
    if not _check(not room.vehicle_collisions,"default OFF"): return
    if not await _sync("default"): return
    if host and enabled:
        var toggle := current_scene.find_child("Vehicle collisions",true,false) as Button
        if not _check(toggle!=null,"collision lobby control"): return
        toggle.pressed.emit()
    if not await _until(func(): return room.vehicle_collisions==enabled,"replicated setting"): return
    current_scene.ready_toggle()
    if host:
        if not await _until(room.can_start,"start enabled"): return
        current_scene.start_game()
    if not await _until(_in_park,"Park free roam"): return
    race = current_scene
    var damage: Node = race.park.damage
    if not _check(damage.parts.all(func(p): return p!=null),"four visible bumper components"): return
    if enabled:
        race.model.reset(Vector2(22,20.8 if host else 16),0)
        race.net.mark_recovered()
        if not await _sync("gentle-ready"): return
        await create_timer(0.8).timeout
        if host: race.model.velocity = Vector2.UP*3.0
        if not await _until(func(): return damage.pushes>0,"gentle contact resolved"): return
        if not _check(damage.mounts==PackedByteArray([3,3,3,3]) and race.model.speed_mps()<3.1 and race.park.air.height<0.02,"low-speed deflection has bounded speed and no damage"): return
        if not await _sync("gentle-end"): return
    for pass_id in (2 if enabled else 1):
        race.model.reset(Vector2(22,24 if host else 16),0)
        race.net.mark_recovered()
        if not await _sync("setup%d"%pass_id): return
        await create_timer(0.9).timeout
        if host:
            race.model.velocity = Vector2(0,-24)
        if enabled:
            var wanted := 1 if pass_id==0 else 0
            if not await _until(func(): return damage.mounts[0]==wanted and damage.mounts[3]==wanted,"front and rear damage phase %d"%pass_id): return
            if not _check(damage.pushes>0 and race.park.air.height<0.02,"planar collision received"): return
            if not _check(damage.mounts[1]==3 and damage.mounts[2]==3,"other bumpers remain intact"): return
            if pass_id==1 and not _check(is_instance_valid(damage.parts[0].debris) and is_instance_valid(damage.parts[3].debris),"both detached objects"): return
        else:
            await create_timer(0.9).timeout
            if not _check(damage.pushes==0 and damage.mounts==PackedByteArray([3,3,3,3]),"OFF allows overlap without damage or impulse"): return
        if not await _sync("hit%d"%pass_id): return
    if enabled:
        # Separate visits ensure the first player's service does not repair the partner.
        for visiting in 2:
            if room.local_index==visiting:
                race.model.reset(SITE.REPAIR.get_center(),0)
                race.net.mark_recovered()
            if not await _until(func(): return damage.mounts[0 if visiting==0 else 3]==3,"service for slot %d"%visiting): return
            if visiting==0 and not _check(damage.mounts[3]==0,"other car still damaged"): return
            if room.local_index==visiting and not _check(race.park._site_notice.text.contains("REPAIRED"),"free service confirmation"): return
            if not await _sync("service%d"%visiting): return
            if room.local_index==visiting:
                race.model.reset(Vector2(28,15),0)
        if not _check(damage.parts[0].debris==null and damage.parts[3].debris==null,"debris retired"): return
    if not await _sync("done"): return
    print("PASS: ",driver," Park collisions ",enabled," host ",host," pushes ",damage.pushes)
    room.leave()
    race.queue_free()
    room.queue_free()
    await process_frame
    await process_frame
    quit()
