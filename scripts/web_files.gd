extends RefCounted
## Picking photos in a browser: Godot's file dialog can't reach your files on the web,
## so this opens the browser's own picker and hands the image bytes back.

static var _callback: JavaScriptObject


static func pick_images(on_image: Callable) -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("""
		window.somewherePickImages = function(cb) {
			var input = document.createElement('input');
			input.type = 'file';
			input.accept = 'image/png,image/jpeg,image/webp';
			input.multiple = true;
			input.onchange = async function() {
				for (const f of input.files) {
					const buf = new Uint8Array(await f.arrayBuffer());
					let s = '';
					for (let k = 0; k < buf.length; k += 8192) { s += String.fromCharCode.apply(null, buf.subarray(k, k + 8192)); }
					cb(f.type, btoa(s));
				}
			};
			input.click();
		};
	""", true)
	_callback = JavaScriptBridge.create_callback(func(args: Array) -> void:
		on_image.call(Marshalls.base64_to_raw(str(args[1])), str(args[0])))
	JavaScriptBridge.get_interface("window").somewherePickImages(_callback)
