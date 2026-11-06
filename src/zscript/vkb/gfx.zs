//===========================================================================
//
// Visual Keybinds - drawing helpers and theme
//
//===========================================================================

class VKB_Gfx : Object ui
{
	// Theme
	static Color PanelColor()   { return Color(255, 17, 19, 25); }
	static Color KeyFree()      { return Color(255, 54, 58, 68); }
	static Color KeyBound()     { return Color(255, 40, 128, 76); }
	static Color KeyCustom()    { return Color(255, 156, 110, 32); }
	static Color KeyMulti()     { return Color(255, 160, 50, 50); }
	static Color KeyDead()      { return Color(255, 31, 33, 39); }
	static Color Accent()       { return Color(255, 86, 164, 255); }
	static Color ButtonColor()  { return Color(255, 44, 48, 58); }
	static Color ButtonHover()  { return Color(255, 62, 68, 82); }
	static Color ButtonActive() { return Color(255, 36, 76, 128); }
	static Color LineColor()    { return Color(255, 70, 74, 86); }

	static Font TextFont()
	{
		return NewSmallFont;
	}

	// Scale that makes the text font 'px' pixels tall.
	static double ScaleFor(double px)
	{
		int h = TextFont().GetHeight();
		if (h <= 0) h = 10;
		return max(0.25, px / h);
	}

	static void Fill(double x, double y, double w, double h, Color c, double alpha = 1.0)
	{
		int x0 = int(x);
		int y0 = int(y);
		int x1 = int(x + w);
		int y1 = int(y + h);
		if (x1 <= x0 || y1 <= y0 || alpha <= 0) return;
		Screen.Dim(c, clamp(alpha, 0.0, 1.0), x0, y0, x1 - x0, y1 - y0);
	}

	static void Outline(double x, double y, double w, double h, Color c, int thickness = 1)
	{
		int x0 = int(x);
		int y0 = int(y);
		int x1 = int(x + w);
		int y1 = int(y + h);
		if (x1 <= x0 || y1 <= y0) return;
		Screen.DrawLineFrame(c, x0, y0, x1 - x0, y1 - y0, max(1, thickness));
	}

	static double TextWidth(String s, double scale)
	{
		return TextFont().StringWidth(s, false) * scale;
	}

	static double TextHeight(double scale)
	{
		return TextFont().GetHeight() * scale;
	}

	static void Text(String s, double x, double y, int cr, double scale, double alpha = 1.0)
	{
		if (s.Length() == 0 || alpha <= 0) return;
		Screen.DrawText(TextFont(), cr, x, y, s,
			DTA_ScaleX, scale, DTA_ScaleY, scale, DTA_Alpha, clamp(alpha, 0.0, 1.0), DTA_Localize, false);
	}

	static void TextCentered(String s, double cx, double y, int cr, double scale, double alpha = 1.0)
	{
		Text(s, cx - TextWidth(s, scale) / 2, y, cr, scale, alpha);
	}

	static void TextRight(String s, double rx, double y, int cr, double scale, double alpha = 1.0)
	{
		Text(s, rx - TextWidth(s, scale), y, cr, scale, alpha);
	}

	// Shortens text with "…" so it fits in maxW pixels.
	static String Fit(String s, double maxW, double scale)
	{
		if (maxW <= 0) return "";
		if (TextWidth(s, scale) <= maxW) return s;

		String dots = "…";
		String res = "";
		int pos = 0;
		int len = s.Length();
		while (pos < len)
		{
			let [ch, nxt] = s.GetNextCodePoint(pos);
			String test = res;
			test.AppendCharacter(ch);
			if (TextWidth(test .. dots, scale) > maxW) break;
			res = test;
			pos = nxt;
		}
		return res.Length() > 0 ? res .. dots : "";
	}

	static bool Inside(double mx, double my, double x, double y, double w, double h)
	{
		return mx >= x && mx < x + w && my >= y && my < y + h;
	}

	// Moves 'value' toward 'target', framerate independent.
	static double Approach(double value, double target, double dt, double speed)
	{
		double f = clamp(dt * speed, 0.0, 1.0);
		return value + (target - value) * f;
	}

	static double EaseOut(double t)
	{
		t = clamp(t, 0.0, 1.0);
		double u = 1.0 - t;
		return 1.0 - u * u * u;
	}

	// Rounded-looking button: flat fill plus a 1px frame.
	static void Button(String label, double x, double y, double w, double h, double textScale,
		bool hover, bool selected, bool enabled = true)
	{
		Color fill = selected ? ButtonActive() : (hover && enabled ? ButtonHover() : ButtonColor());
		Fill(x, y, w, h, fill, enabled ? 0.95 : 0.55);
		Outline(x, y, w, h, selected ? Accent() : LineColor(), 1);
		int cr = !enabled ? Font.CR_DARKGRAY : (selected ? Font.CR_WHITE : (hover ? Font.CR_WHITE : Font.CR_GRAY));
		String t = Fit(label, w - h * 0.4, textScale);
		TextCentered(t, x + w / 2, y + (h - TextHeight(textScale)) / 2, cr, textScale);
	}
}

// One clickable area, rebuilt every frame by the screen that draws it.
class VKB_Hit : Object ui
{
	int mId;
	double mX, mY, mW, mH;
	bool mEnabled;
}

class VKB_HitList : Object ui
{
	Array<VKB_Hit> mHits;

	void Clear()
	{
		mHits.Clear();
	}

	void Add(int id, double x, double y, double w, double h, bool enabled = true)
	{
		let hit = new("VKB_Hit");
		hit.mId = id;
		hit.mX = x;
		hit.mY = y;
		hit.mW = w;
		hit.mH = h;
		hit.mEnabled = enabled;
		mHits.Push(hit);
	}

	// Id under the point, or -1. Disabled areas still block what's below.
	int At(double mx, double my, bool includeDisabled = false)
	{
		for (int i = mHits.Size() - 1; i >= 0; i--)
		{
			let hit = mHits[i];
			if (VKB_Gfx.Inside(mx, my, hit.mX, hit.mY, hit.mW, hit.mH))
			{
				if (!hit.mEnabled && !includeDisabled) return -1;
				return hit.mId;
			}
		}
		return -1;
	}
}
