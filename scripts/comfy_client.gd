extends Node
## Talks only to a local ComfyUI server. Generation uses built-in nodes and
## never downloads models, launches processes, or interrupts other queued jobs.

signal progress(message: String)

const DEFAULT_ENDPOINT = "http://127.0.0.1:8188"
const JOB_TIMEOUT_SECONDS = 1200.0
const POLL_INTERVAL_SECONDS = 1.0
const MAX_RESPONSE_BYTES = 48 * 1024 * 1024

class PendingReply extends RefCounted:
	signal finished
	var done := false
	var result: Dictionary = {}

	func resolve(value: Dictionary) -> void:
		if done:
			return
		done = true
		result = value
		finished.emit()

var _busy := false
var _cancelled := false
var _serial := 0
var _request_node: HTTPRequest
var _pending: PendingReply

func probe_server(endpoint: String) -> Dictionary:
	if _busy:
		return {"ok": false, "checkpoints": [], "error": "Another local artwork request is already running."}
	var address = _validate_endpoint(endpoint)
	if not address.ok:
		return {"ok": false, "checkpoints": [], "error": address.error}
	if not is_inside_tree():
		return {"ok": false, "checkpoints": [], "error": "Add the local artwork client to the scene tree before connecting."}
	var operation = _begin()
	progress.emit("Connecting to local ComfyUI…")
	var response = await _request(str(address.url) + "/object_info/CheckpointLoaderSimple", HTTPClient.METHOD_GET, "", 10.0, operation)
	var output = {"ok": false, "checkpoints": [], "error": ""}
	if not response.ok:
		output.error = response.error
		output["cancelled"] = response.get("cancelled", false)
	else:
		var data: Variant = _parse_json(response.body)
		if not data is Dictionary:
			output.error = "The local server returned invalid ComfyUI checkpoint information. Check the address and start ComfyUI."
		else:
			var loader: Variant = data.get("CheckpointLoaderSimple", {})
			var input: Variant = loader.get("input", {}) if loader is Dictionary else {}
			var required: Variant = input.get("required", {}) if input is Dictionary else {}
			var names: Variant = required.get("ckpt_name", []) if required is Dictionary else []
			var valid_names = names is Array and names.size() > 0 and names[0] is Array
			if valid_names:
				for name in names[0]:
					if name is String and not name.strip_edges().is_empty():
						output.checkpoints.append(name)
			if not valid_names:
				output.error = "This server did not expose ComfyUI's standard checkpoint loader. Check the address and use a running ComfyUI installation with CheckpointLoaderSimple available."
			elif output.checkpoints.is_empty():
				output.error = "ComfyUI is reachable, but has no checkpoint models. Add a compatible SDXL checkpoint to ComfyUI's models/checkpoints folder, then refresh the connection."
			else:
				output.ok = true
				progress.emit("Connected. Found %d local checkpoint(s)." % output.checkpoints.size())
	_end(operation)
	return output

func generate_image(endpoint: String, checkpoint: String, prompt: String, negative: String, seed: int, width: int, height: int, steps: int = 20) -> Dictionary:
	if _busy:
		return _failure("Another local artwork request is already running.")
	var address = _validate_endpoint(endpoint)
	if not address.ok:
		return _failure(str(address.error))
	if not is_inside_tree():
		return _failure("Add the local artwork client to the scene tree before generating.")
	if checkpoint.strip_edges().is_empty():
		return _failure("Choose an installed SDXL checkpoint before generating artwork.")
	if prompt.strip_edges().is_empty():
		return _failure("Describe the artwork you want to generate.")
	if width < 512 or width > 1024 or height < 512 or height > 1024 or width % 64 != 0 or height % 64 != 0:
		return _failure("Image width and height must each be 512–1024 pixels in multiples of 64. Start with 768 × 768 on an 8 GB GPU.")
	if steps < 1 or steps > 100:
		return _failure("Choose between 1 and 100 sampling steps; 20 is a useful starting point.")
	if seed < 0:
		return _failure("The artwork seed must be zero or a positive whole number.")
	var operation = _begin()
	var base = str(address.url)
	var workflow = build_workflow(checkpoint, prompt, negative, seed, width, height, steps)
	progress.emit("Sending artwork prompt to local ComfyUI…")
	var submitted = await _request(base + "/prompt", HTTPClient.METHOD_POST, JSON.stringify({"prompt": workflow}), 30.0, operation)
	if not submitted.ok:
		_end(operation)
		return _failure(str(submitted.error), "", bool(submitted.get("cancelled", false)))
	var accepted: Variant = _parse_json(submitted.body)
	if not accepted is Dictionary or not accepted.get("prompt_id", "") is String or str(accepted.get("prompt_id", "")).is_empty():
		_end(operation)
		return _failure("ComfyUI did not accept the artwork workflow. " + _server_message(submitted.body))
	var prompt_id = str(accepted.prompt_id)
	var started = Time.get_ticks_msec()
	var next_notice = 0.0
	progress.emit("Artwork queued locally. The first image may take longer while the checkpoint loads.")
	while not _is_cancelled(operation):
		var elapsed = (Time.get_ticks_msec() - started) / 1000.0
		if elapsed >= JOB_TIMEOUT_SECONDS:
			_end(operation)
			return _failure("Timed out after 20 minutes waiting for local artwork. Check ComfyUI's queue and console. The job may still finish in ComfyUI; no other jobs were interrupted.", prompt_id)
		var history = await _request(base + "/history/" + prompt_id.uri_encode(), HTTPClient.METHOD_GET, "", 20.0, operation)
		if not history.ok:
			_end(operation)
			return _failure(str(history.error), prompt_id, bool(history.get("cancelled", false)))
		var records: Variant = _parse_json(history.body)
		if not records is Dictionary:
			_end(operation)
			return _failure("ComfyUI returned invalid generation history. Check its console and try again.", prompt_id)
		var record: Variant = records.get(prompt_id, {})
		if record is Dictionary and not record.is_empty():
			var execution_error = _execution_error(record)
			if not execution_error.is_empty():
				_end(operation)
				return _failure(_actionable_error(execution_error), prompt_id)
			var image_info = _find_image(record)
			if not image_info.is_empty():
				progress.emit("Receiving generated artwork from local ComfyUI…")
				var query = "filename=" + str(image_info.filename).uri_encode()
				query += "&subfolder=" + str(image_info.get("subfolder", "")).uri_encode()
				query += "&type=" + str(image_info.get("type", "output")).uri_encode()
				var downloaded = await _request(base + "/view?" + query, HTTPClient.METHOD_GET, "", 30.0, operation)
				if not downloaded.ok:
					_end(operation)
					return _failure(str(downloaded.error), prompt_id, bool(downloaded.get("cancelled", false)))
				var image = _decode_image(downloaded.body)
				if image == null:
					_end(operation)
					return _failure("ComfyUI returned an unreadable image. Its /view endpoint must return PNG, JPEG, or WebP image bytes.", prompt_id)
				if _is_cancelled(operation):
					_end(operation)
					return _failure(_cancel_message(), prompt_id, true)
				_end(operation)
				progress.emit("Local artwork is ready.")
				return {"ok": true, "image": image, "prompt_id": prompt_id, "error": ""}
			var status: Variant = record.get("status", {})
			if status is Dictionary and (status.get("completed", false) or status.get("status_str", "") == "success"):
				_end(operation)
				return _failure("ComfyUI finished without an image output. Check the SaveImage node and the server console.", prompt_id)
		if elapsed >= next_notice:
			progress.emit("Waiting for local artwork (%d seconds). ComfyUI may be loading the model, sampling, or finishing an earlier queued job." % int(elapsed))
			next_notice = elapsed + 15.0
		if not await _pause(POLL_INTERVAL_SECONDS, operation):
			break
	_end(operation)
	return _failure(_cancel_message(), prompt_id, true)

func cancel() -> void:
	if not _busy:
		return
	_cancelled = true
	if is_instance_valid(_request_node):
		_request_node.cancel_request()
	# HTTPRequest.cancel_request() does not emit request_completed. Resolve our
	# own await explicitly, including when cancellation happens between polls.
	var pending = _pending
	if pending != null:
		pending.resolve({"ok": false, "error": _cancel_message(), "cancelled": true})

static func build_workflow(checkpoint: String, prompt: String, negative: String, seed: int, width: int, height: int, steps: int = 20) -> Dictionary:
	return {
		"4": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": checkpoint}},
		"6": {"class_type": "CLIPTextEncode", "inputs": {"text": prompt, "clip": ["4", 1]}},
		"7": {"class_type": "CLIPTextEncode", "inputs": {"text": negative, "clip": ["4", 1]}},
		"5": {"class_type": "EmptyLatentImage", "inputs": {"width": width, "height": height, "batch_size": 1}},
		"3": {"class_type": "KSampler", "inputs": {"seed": seed, "steps": steps, "cfg": 7.0,
			"sampler_name": "dpmpp_2m", "scheduler": "karras", "denoise": 1.0,
			"model": ["4", 0], "positive": ["6", 0], "negative": ["7", 0], "latent_image": ["5", 0]}},
		"8": {"class_type": "VAEDecode", "inputs": {"samples": ["3", 0], "vae": ["4", 2]}},
		"9": {"class_type": "SaveImage", "inputs": {"images": ["8", 0], "filename_prefix": "UIForge"}},
	}

static func _validate_endpoint(endpoint: String) -> Dictionary:
	var candidate = endpoint.strip_edges().to_lower()
	if candidate.is_empty():
		candidate = DEFAULT_ENDPOINT
	var pattern = RegEx.new()
	pattern.compile("^http://(localhost|127\\.0\\.0\\.1|\\[::1\\])(?::([0-9]{1,5}))?/?$")
	var matched = pattern.search(candidate)
	if matched == null:
		return {"ok": false, "error": "Use a local HTTP ComfyUI address such as http://127.0.0.1:8188. Only localhost, 127.0.0.1, and [::1] are supported; paths, credentials, and remote servers are not accepted."}
	var port = matched.get_string(2)
	if not port.is_empty() and (int(port) < 1 or int(port) > 65535):
		return {"ok": false, "error": "The local ComfyUI port must be between 1 and 65535."}
	return {"ok": true, "url": candidate.trim_suffix("/")}

func _begin() -> int:
	_busy = true
	_cancelled = false
	_serial += 1
	return _serial

func _end(operation: int) -> void:
	if operation == _serial:
		_busy = false

func _is_cancelled(operation: int) -> bool:
	return _cancelled or operation != _serial

func _request(url: String, method: HTTPClient.Method, body: String, timeout: float, operation: int) -> Dictionary:
	if _is_cancelled(operation):
		return {"ok": false, "error": _cancel_message(), "cancelled": true}
	var request = HTTPRequest.new()
	request.timeout = timeout
	request.body_size_limit = MAX_RESPONSE_BYTES
	request.max_redirects = 0
	# HTTPRequest's normal mode polls a nonblocking HTTPClient every frame.
	# Threaded mode joins its worker in cancel_request(), which can freeze the
	# editor while a local server is busy. Keep cancellation on the polling path.
	request.use_threads = false
	add_child(request)
	_request_node = request
	var pending = PendingReply.new()
	_pending = pending
	request.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, bytes: PackedByteArray):
		if result != HTTPRequest.RESULT_SUCCESS:
			var detail = "The local ComfyUI request failed. Start ComfyUI, keep its window open, and verify the local server address."
			if result == HTTPRequest.RESULT_TIMEOUT:
				detail = "The local ComfyUI server did not respond in time. Check its console and address; it may still be processing the image."
			elif result == HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
				detail = "ComfyUI returned a response larger than 48 MB. Generate a smaller image and try again."
			elif result == HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED:
				detail = "The local server redirected this request. Use ComfyUI's direct localhost address; redirects are not followed."
			pending.resolve({"ok": false, "error": detail, "response_code": response_code})
		elif response_code < 200 or response_code >= 300:
			pending.resolve({"ok": false, "error": _actionable_error("ComfyUI returned HTTP %d. %s" % [response_code, _server_message(bytes)]), "response_code": response_code})
		else:
			pending.resolve({"ok": true, "body": bytes, "response_code": response_code})
	)
	var headers = PackedStringArray(["Accept: application/json, image/png, image/jpeg, image/webp"])
	if method == HTTPClient.METHOD_POST:
		headers.append("Content-Type: application/json")
	var error = request.request(url, headers, method, body)
	if error != OK:
		pending.resolve({"ok": false, "error": "Could not contact local ComfyUI (error %d). Start ComfyUI and verify its address." % error})
	if not pending.done:
		await pending.finished
	if _pending == pending:
		_pending = null
		_request_node = null
	request.queue_free()
	if _is_cancelled(operation):
		return {"ok": false, "error": _cancel_message(), "cancelled": true}
	return pending.result

func _pause(seconds: float, operation: int) -> bool:
	if _is_cancelled(operation):
		return false
	var pending = PendingReply.new()
	_pending = pending
	get_tree().create_timer(seconds).timeout.connect(func(): pending.resolve({"ok": true}))
	if not pending.done:
		await pending.finished
	if _pending == pending:
		_pending = null
	return not _is_cancelled(operation)

static func _find_image(record: Dictionary) -> Dictionary:
	var outputs: Variant = record.get("outputs", {})
	if not outputs is Dictionary:
		return {}
	for key in outputs:
		var output: Variant = outputs[key]
		if not output is Dictionary:
			continue
		var images: Variant = output.get("images", [])
		if not images is Array:
			continue
		for image in images:
			if image is Dictionary and image.get("filename", "") is String and not str(image.get("filename", "")).is_empty():
				return image
	return {}

static func _execution_error(record: Dictionary) -> String:
	var status: Variant = record.get("status", {})
	if not status is Dictionary:
		return ""
	var messages: Variant = status.get("messages", [])
	if messages is Array:
		for message in messages:
			if not message is Array or message.size() < 2:
				continue
			if message[0] == "execution_interrupted":
				return "ComfyUI interrupted this image generation. Try generating again when it is ready."
			if message[0] == "execution_error" and message[1] is Dictionary:
				return "ComfyUI could not generate the image (%s): %s" % [str(message[1].get("node_type", "workflow")), str(message[1].get("exception_message", "Check its console for details.")).left(700)]
	if status.get("status_str", "") == "error":
		return "ComfyUI could not generate this image. Check the server console for the workflow error."
	return ""

static func _server_message(bytes: PackedByteArray) -> String:
	var data: Variant = _parse_json(bytes)
	if not data is Dictionary:
		return "Check ComfyUI's console and the selected checkpoint."
	var parts: Array[String] = []
	var error: Variant = data.get("error", "")
	if error is Dictionary:
		for key in ["message", "details"]:
			if not str(error.get(key, "")).is_empty():
				parts.append(str(error[key]))
	elif not str(error).is_empty():
		parts.append(str(error))
	var node_errors: Variant = data.get("node_errors", {})
	if node_errors is Dictionary:
		for node in node_errors.values():
			if not node is Dictionary or not node.get("errors", []) is Array:
				continue
			for detail in node.errors:
				if detail is Dictionary:
					parts.append(str(detail.get("details", detail.get("message", ""))))
	return " ".join(parts).left(900) if not parts.is_empty() else "Check ComfyUI's console and the selected checkpoint."

static func _parse_json(bytes: PackedByteArray) -> Variant:
	# A malformed local API response is an expected transport error. JSON.parse
	# returns an error code, avoiding parse_string's engine-error log message.
	var parser = JSON.new()
	if parser.parse(bytes.get_string_from_utf8()) != OK:
		return null
	return parser.data

static func _actionable_error(message: String) -> String:
	var lower = message.to_lower()
	if "out of memory" in lower or "outofmemory" in lower or "cuda oom" in lower or "alloc_failed" in lower:
		return message + " On an 8 GB GPU, close GPU-heavy apps, use a compatible SDXL base checkpoint with batch size 1, and try 768 × 768 or 512 × 512. If needed, restart ComfyUI with --disable-dynamic-vram --lowvram; use --cpu-vae if decoding the image runs out of memory."
	return message

static func _decode_image(bytes: PackedByteArray) -> Image:
	var image = Image.new()
	var error = ERR_FILE_UNRECOGNIZED
	if bytes.size() >= 8 and bytes[0] == 137 and bytes[1] == 80 and bytes[2] == 78 and bytes[3] == 71:
		error = image.load_png_from_buffer(bytes)
	elif bytes.size() >= 3 and bytes[0] == 255 and bytes[1] == 216:
		error = image.load_jpg_from_buffer(bytes)
	elif bytes.size() >= 12 and bytes.slice(0, 4).get_string_from_ascii() == "RIFF" and bytes.slice(8, 12).get_string_from_ascii() == "WEBP":
		error = image.load_webp_from_buffer(bytes)
	return image if error == OK and not image.is_empty() else null

static func _cancel_message() -> String:
	return "Local artwork generation was cancelled in UI Forge. A running ComfyUI image may still finish; other jobs were not interrupted."

static func _failure(message: String, prompt_id: String = "", cancelled: bool = false) -> Dictionary:
	return {"ok": false, "image": null, "prompt_id": prompt_id, "error": message, "cancelled": cancelled}

func _exit_tree() -> void:
	cancel()
