class_name SheetUtil
# Builds a SpriteFrames from horizontal-strip PixelFrog sheets.
# specs: Array of { name, path, w, h, count, fps, loop }

static func frames(specs: Array) -> SpriteFrames:
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	for s in specs:
		var anim: String = s.name
		sf.add_animation(anim)
		sf.set_animation_loop(anim, s.get("loop", true))
		sf.set_animation_speed(anim, s.get("fps", 10.0))
		var tex: Texture2D = load(s.path) as Texture2D
		if tex == null:
			continue
		var count: int = s.count
		for i in range(count):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * s.w, 0, s.w, s.h)
			at.filter_clip = true  # stop sampling bleeding into neighbouring frames
			sf.add_frame(anim, at)
	return sf

# Single-frame AtlasTexture (for static icons / first frame of a sheet).
static func first_frame(path: String, w: int, h: int) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = load(path) as Texture2D
	at.region = Rect2(0, 0, w, h)
	at.filter_clip = true
	return at
