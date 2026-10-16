@tool
extends RefCounted
## Update only an existing, clean checkout; never reset, stash, or force a merge.

static func find_git() -> String:
	var windows = OS.get_name() == "Windows"
	var executable = "git.exe" if windows else "git"
	var paths = Array(OS.get_environment("PATH").split(";" if windows else ":", false))
	if windows:
		for variable in ["ProgramFiles", "ProgramW6432", "LOCALAPPDATA"]:
			var base = OS.get_environment(variable)
			if not base.is_empty():
				paths.append(base.path_join("Git/cmd"))
				paths.append(base.path_join("Programs/Git/cmd"))
	for path in paths:
		var candidate = str(path).strip_edges().trim_prefix('"').trim_suffix('"').path_join(executable)
		if FileAccess.file_exists(candidate):
			return candidate
	return ""

static func _run(git: String, directory: String, arguments: Array) -> Dictionary:
	var output: Array = []
	var args = PackedStringArray(["-C", directory])
	args.append_array(PackedStringArray(arguments))
	var code = OS.execute(git, args, output, true)
	return {"code": code, "output": "\n".join(output).strip_edges()}

static func _path(value: String) -> String:
	var result = value.replace("\\", "/").simplify_path().trim_suffix("/")
	return result.to_lower() if OS.get_name() == "Windows" else result

static func update_checkout(directory: String) -> Dictionary:
	var git = find_git()
	if git.is_empty():
		return {"ok": false, "message": "Git was not found. Install Git for Windows with command-line access enabled, then restart Godot. On other platforms, install Git and make it available in PATH."}
	var checkout = _run(git, directory, ["rev-parse", "--show-toplevel"])
	if checkout.code != 0:
		return {"ok": false, "message": "This project is not a Git clone. Clone Ruslanf89/UI_Generator once with Git, then import the clone's project.godot. A downloaded source ZIP has no Git history. Your existing files have not been changed."}
	if _path(checkout.output) != _path(directory):
		return {"ok": false, "message": "The project is inside another repository. Open a separate clone of UI_Generator so an update cannot modify the parent repository."}
	var branch = _run(git, directory, ["symbolic-ref", "--quiet", "--short", "HEAD"])
	if branch.code != 0 or branch.output != "main":
		return {"ok": false, "message": "Switch this checkout to the main branch before updating. The current branch or detached HEAD was left unchanged."}
	var status = _run(git, directory, ["status", "--porcelain=v1", "--untracked-files=normal"])
	if status.code != 0:
		return {"ok": false, "message": "Could not check local changes. No update was attempted.\n\n" + status.output}
	if not status.output.is_empty():
		return {"ok": false, "message": "This checkout has local changes. Commit or back up your changes before updating. Nothing was reset, stashed, or overwritten.\n\n" + status.output.left(2000)}
	var remote = _run(git, directory, ["remote", "get-url", "origin"])
	if remote.code != 0:
		return {"ok": false, "message": "This checkout has no origin remote. Use the Git clone created from Ruslanf89/UI_Generator, or configure the intended origin in your Git client."}
	var pull = _run(git, directory, ["-c", "credential.interactive=false", "-c", "http.lowSpeedLimit=1", "-c", "http.lowSpeedTime=30", "pull", "--ff-only", "--no-rebase", "origin", "main"])
	if pull.code != 0:
		return {"ok": false, "message": "Update could not fast-forward. Local files and commits were kept. Check your network, Git authentication, and any divergent commits in your Git client.\n\n" + pull.output.left(3000)}
	return {"ok": true, "message": "The checkout is up to date with origin/main. Godot will rescan changed files; follow any editor reload prompts.\n\n" + pull.output.left(3000)}
