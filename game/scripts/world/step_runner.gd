extends RefCounted
class_name NitroSteps
## Long jobs (terrain generation, road adaptation, track loading) as a list
## of small steps, so the UI can run them across several frames and keep a
## loading animation moving instead of freezing the app. A step is a
## Callable; when it returns an Array of Callables, those run next (steps
## whose work depends on an earlier step, e.g. the chunks a road touched).
## run_now() executes everything at once (tests, headless tools).

static func run_now(steps: Array) -> void:
    var queue: Array = steps.duplicate()
    while not queue.is_empty():
        var step: Callable = queue.pop_front()
        var more: Variant = step.call()
        if more is Array and not (more as Array).is_empty():
            queue = (more as Array)+queue

## Runs the steps, yielding a frame whenever budget_ms of work has been done.
## progress (optional) gets the fraction of steps done (known steps only).
static func run_sliced(steps: Array, tree: SceneTree, budget_ms: float = 35.0,
        progress: Callable = Callable()) -> void:
    var queue: Array = steps.duplicate()
    var done: int = 0
    var t0: int = Time.get_ticks_usec()
    while not queue.is_empty():
        var step: Callable = queue.pop_front()
        var more: Variant = step.call()
        done += 1
        if more is Array and not (more as Array).is_empty():
            queue = (more as Array)+queue
        if float(Time.get_ticks_usec()-t0)/1000.0 >= budget_ms:
            if progress.is_valid():
                progress.call(float(done)/float(done+queue.size()))
            await tree.process_frame
            t0 = Time.get_ticks_usec()
    if progress.is_valid():
        progress.call(1.0)
