//===========================================================================
//
// Visual Keybinds - keyboard screen
//
// Shows a keyboard and the mouse buttons, colored by what each one does.
// Hover or move the cursor to inspect a key; click it (or press Enter)
// to open the editor for that key.
//
// Keyboard and gamepad:
//   arrows / d-pad      move between keys
//   Enter / A           edit the key
//   PgUp / PgDn, LB/RB  switch between Game, Double tap and Automap
//   Home / End          switch keyboard size
//
//===========================================================================

class VKB_KeyboardMenu : GenericMenu
{
	enum EKeyState
	{
		KS_DEAD,      // can't be bound (Esc, Fn)
		KS_FREE,
		KS_BOUND,     // one known action
		KS_CUSTOM,    // a command that isn't in the controls menus
		KS_MULTI      // several commands on one key
	}

	enum EButtons
	{
		BTN_LAYOUT = 100,   // + layout index
		BTN_VIEW = 200,     // + binding set
		BTN_LIST = 300,
		BTN_DONE = 301,
		BTN_KEY = 1000      // + key index
	}

	VKB_Catalog mCatalog;
	VKB_Board mBoard;
	VKB_Board mMouse;

	Array<VKB_Key> mKeys;       // keyboard keys followed by mouse buttons
	Array<int> mState;
	Array<String> mShort;       // action shown on the keycap
	int mBoardCount;            // how many of mKeys are keyboard keys

	// Screen rectangles of the keys, from the last layout.
	Array<double> mKX;
	Array<double> mKY;
	Array<double> mKW;
	Array<double> mKH;

	int mLayout;
	int mView;
	int mSel;
	int mHoverBtn;
	double mMouseX, mMouseY;

	double mOpenTime;
	double mLastTime;
	int mRefreshTimer;

	int mUsedKeys;
	int mMultiKeys;

	VKB_HitList mHits;

	//=======================================================================
	//
	// Setup
	//
	//=======================================================================

	override void Init(Menu parent)
	{
		Super.Init(parent);

		mCatalog = VKB_Catalog.Create();
		mHits = new("VKB_HitList");

		mLayout = clamp(GetInt('vkb_layout', 0), 0, 2);
		mView = 0;
		mSel = -1;
		mHoverBtn = -1;
		mMouseX = -1;
		mMouseY = -1;

		BuildKeys();
		mSel = FindKeyIndex(17); // W
		if (mSel < 0) mSel = 0;

		mOpenTime = MSTimeF();
		mLastTime = mOpenTime;
		Refresh();
	}

	static int GetInt(Name cvarName, int fallback)
	{
		let cv = CVar.FindCVar(cvarName);
		return cv != null ? cv.GetInt() : fallback;
	}

	private void BuildKeys()
	{
		mBoard = VKB_Board.Create(mLayout);
		mMouse = VKB_Board.CreateMouse();

		mKeys.Clear();
		for (int i = 0; i < mBoard.mKeys.Size(); i++) mKeys.Push(mBoard.mKeys[i]);
		mBoardCount = mKeys.Size();
		for (int i = 0; i < mMouse.mKeys.Size(); i++) mKeys.Push(mMouse.mKeys[i]);

		mState.Clear();
		mShort.Clear();
		mKX.Clear();
		mKY.Clear();
		mKW.Clear();
		mKH.Clear();
		for (int i = 0; i < mKeys.Size(); i++)
		{
			mState.Push(KS_FREE);
			mShort.Push("");
			mKX.Push(0);
			mKY.Push(0);
			mKW.Push(0);
			mKH.Push(0);
		}
	}

	private int FindKeyIndex(int code)
	{
		for (int i = 0; i < mKeys.Size(); i++)
		{
			if (mKeys[i].mCode == code && mKeys[i].mBindable) return i;
		}
		return -1;
	}

	private void SetLayout(int layout)
	{
		layout = clamp(layout, 0, 2);
		if (layout == mLayout) return;

		int selCode = mSel >= 0 && mSel < mKeys.Size() ? mKeys[mSel].mCode : 0;
		mLayout = layout;
		BuildKeys();
		mSel = selCode > 0 ? FindKeyIndex(selCode) : -1;
		if (mSel < 0) mSel = FindKeyIndex(17);
		if (mSel < 0) mSel = 0;

		let cv = CVar.FindCVar('vkb_layout');
		if (cv != null) cv.SetInt(mLayout);

		mOpenTime = MSTimeF(); // replay the entrance animation
		Refresh();
		MenuSound("menu/change");
	}

	private void SetView(int view)
	{
		view = (view % VKB_Catalog.NUM_SETS + VKB_Catalog.NUM_SETS) % VKB_Catalog.NUM_SETS;
		if (view == mView) return;
		mView = view;
		Refresh();
		MenuSound("menu/change");
	}

	// Recomputes what every key does in the current view.
	void Refresh()
	{
		mUsedKeys = 0;
		mMultiKeys = 0;
		Array<String> cmds;

		for (int i = 0; i < mKeys.Size(); i++)
		{
			let k = mKeys[i];
			if (!k.mBindable)
			{
				mState[i] = KS_DEAD;
				mShort[i] = "";
				continue;
			}

			String binding = VKB_Catalog.GetBinding(mView, k.mCode);
			VKB_Catalog.SplitCommands(binding, cmds);

			if (cmds.Size() == 0)
			{
				mState[i] = KS_FREE;
				mShort[i] = "";
				continue;
			}

			mUsedKeys++;
			if (cmds.Size() > 1)
			{
				mState[i] = KS_MULTI;
				mMultiKeys++;
				mShort[i] = String.Format("%d×", cmds.Size());
				continue;
			}

			let a = mCatalog.FindAction(mView, cmds[0]);
			mState[i] = a != null ? KS_BOUND : KS_CUSTOM;
			mShort[i] = a != null ? a.mLabel : cmds[0];
		}
		mRefreshTimer = 0;
	}

	override void OnReturn()
	{
		// Back from the editor or the controls list: bindings may have changed.
		Refresh();
	}

	override void Ticker()
	{
		Super.Ticker();
		// Bindings can also change from the console while the menu is open.
		if (++mRefreshTimer >= 35) Refresh();
	}

	//=======================================================================
	//
	// Layout
	//
	//=======================================================================

	double mMargin;
	double mTitleY, mTitleScale;
	double mStatusY;
	double mToolbarY, mToolbarH;
	double mUnit;
	double mBoardX, mBoardY;
	double mMouseRowX, mMouseRowY;
	double mLegendY;
	double mInfoY, mInfoH;
	double mFooterY, mFooterH;
	double mTextScale, mSmallScale;

	private void DoLayout()
	{
		double sw = Screen.GetWidth();
		double sh = Screen.GetHeight();

		mMargin = max(8.0, min(sw, sh) * 0.035);
		mTitleScale = VKB_Gfx.ScaleFor(sh * 0.042);
		mTextScale = VKB_Gfx.ScaleFor(sh * 0.026);
		mSmallScale = VKB_Gfx.ScaleFor(sh * 0.021);

		double lineH = VKB_Gfx.TextHeight(mTextScale);

		mTitleY = mMargin;
		mStatusY = mTitleY + VKB_Gfx.TextHeight(mTitleScale) + lineH * 0.25;
		mToolbarY = mStatusY + VKB_Gfx.TextHeight(mSmallScale) + lineH * 0.8;
		mToolbarH = lineH * 1.7;

		mFooterH = lineH * 1.8;
		mFooterY = sh - mMargin - mFooterH;
		mInfoH = lineH * 5.2;
		mInfoY = mFooterY - lineH * 0.7 - mInfoH;
		mLegendY = mInfoY - lineH * 1.6;

		// Keyboard plus a mouse row (0.4 gap + 1 row), fitted in what's left.
		double top = mToolbarY + mToolbarH + lineH * 0.9;
		double bottom = mLegendY - lineH * 0.5;
		double rows = mBoard.mHeight + 0.4 + mMouse.mHeight;
		double cols = max(mBoard.mWidth, mMouse.mWidth);
		mUnit = min((sw - mMargin * 2) / cols, (bottom - top) / rows);
		mUnit = max(mUnit, 8.0);

		double boardW = mBoard.mWidth * mUnit;
		double totalH = rows * mUnit;
		mBoardX = (sw - boardW) / 2;
		mBoardY = top + max(0.0, (bottom - top - totalH) / 2);
		mMouseRowX = (sw - mMouse.mWidth * mUnit) / 2;
		mMouseRowY = mBoardY + (mBoard.mHeight + 0.4) * mUnit;

		double gap = mUnit * 0.07;
		for (int i = 0; i < mKeys.Size(); i++)
		{
			let k = mKeys[i];
			double ox = i < mBoardCount ? mBoardX : mMouseRowX;
			double oy = i < mBoardCount ? mBoardY : mMouseRowY;
			mKX[i] = ox + k.mX * mUnit + gap / 2;
			mKY[i] = oy + k.mY * mUnit + gap / 2;
			mKW[i] = k.mW * mUnit - gap;
			mKH[i] = k.mH * mUnit - gap;
		}
	}

	//=======================================================================
	//
	// Input
	//
	//=======================================================================

	override bool OnUIEvent(UIEvent ev)
	{
		if (ev.type == UIEvent.Type_MouseMove || ev.type == UIEvent.Type_LButtonDown)
		{
			// Track the pointer ourselves so hovering works with every
			// "mouse in menus" setting.
			mMouseX = ev.MouseX;
			mMouseY = ev.MouseY;
			UpdateHover();
		}
		return Super.OnUIEvent(ev);
	}

	private void UpdateHover()
	{
		int id = mHits.At(mMouseX, mMouseY, true);
		if (id >= BTN_KEY)
		{
			int idx = id - BTN_KEY;
			if (idx != mSel && idx < mKeys.Size())
			{
				mSel = idx;
			}
			mHoverBtn = -1;
		}
		else
		{
			mHoverBtn = id;
		}
	}

	override bool MouseEvent(int type, int x, int y)
	{
		if (type != MOUSE_Click) return true;

		int id = mHits.At(x, y);
		if (id < 0) return false;

		if (id >= BTN_KEY)
		{
			mSel = id - BTN_KEY;
			OpenEditor();
		}
		else if (id >= BTN_LAYOUT && id < BTN_LAYOUT + 3)
		{
			SetLayout(id - BTN_LAYOUT);
		}
		else if (id >= BTN_VIEW && id < BTN_VIEW + VKB_Catalog.NUM_SETS)
		{
			SetView(id - BTN_VIEW);
		}
		else if (id == BTN_LIST)
		{
			MenuSound("menu/choose");
			Menu.SetMenu('CustomizeControls');
		}
		else if (id == BTN_DONE)
		{
			MenuEvent(MKEY_Back, false);
		}
		return true;
	}

	override bool MenuEvent(int mkey, bool fromcontroller)
	{
		switch (mkey)
		{
		case MKEY_Up:    MoveSelection(0, -1); return true;
		case MKEY_Down:  MoveSelection(0, 1);  return true;
		case MKEY_Left:  MoveSelection(-1, 0); return true;
		case MKEY_Right: MoveSelection(1, 0);  return true;

		case MKEY_PageUp:   SetView(mView - 1); return true;
		case MKEY_PageDown: SetView(mView + 1); return true;
		case MKEY_Home:     SetLayout(mLayout - 1); return true;
		case MKEY_End:      SetLayout(mLayout + 1); return true;

		case MKEY_Enter:
			OpenEditor();
			return true;
		}
		return Super.MenuEvent(mkey, fromcontroller);
	}

	// Picks the nearest key in a direction, preferring keys in line.
	private void MoveSelection(int dx, int dy)
	{
		if (mKeys.Size() == 0) return;
		if (mSel < 0) { mSel = 0; return; }

		double cx = KeyCenterX(mSel);
		double cy = KeyCenterY(mSel);

		int best = -1;
		double bestScore = 1e9;
		for (int i = 0; i < mKeys.Size(); i++)
		{
			if (i == mSel) continue;
			double ddx = KeyCenterX(i) - cx;
			double ddy = KeyCenterY(i) - cy;
			double along = ddx * dx + ddy * dy;
			if (along <= 0.05) continue;
			double across = abs(dx != 0 ? ddy : ddx);
			double score = along + across * 2.5;
			if (score < bestScore)
			{
				bestScore = score;
				best = i;
			}
		}
		if (best >= 0)
		{
			mSel = best;
			MenuSound("menu/cursor");
		}
	}

	// Key centers in key units, with the mouse row placed under the board.
	private double KeyCenterX(int i)
	{
		let k = mKeys[i];
		double off = 0;
		if (i >= mBoardCount) off = (mBoard.mWidth - mMouse.mWidth) / 2;
		return off + k.mX + k.mW / 2;
	}

	private double KeyCenterY(int i)
	{
		let k = mKeys[i];
		double off = i >= mBoardCount ? mBoard.mHeight + 0.4 : 0.0;
		return off + k.mY + k.mH / 2;
	}

	private void OpenEditor()
	{
		if (mSel < 0 || mSel >= mKeys.Size()) return;
		let k = mKeys[mSel];
		if (!k.mBindable)
		{
			MenuSound("menu/invalid");
			return;
		}
		MenuSound("menu/choose");
		let ed = new("VKB_EditorMenu");
		ed.Init(self);
		ed.Setup(mCatalog, k.mCode, KeyLabel(k), mView);
		ed.ActivateMenu();
	}

	static String KeyLabel(VKB_Key k)
	{
		String label = StringTable.Localize(k.mLabel);
		String engineName = VKB_Catalog.KeyName(k.mCode);
		// Show the engine name when the cap shows a symbol or a short form.
		if (engineName.Length() > 0 && !(engineName ~== label))
		{
			return String.Format("%s (%s)", label, engineName);
		}
		return label;
	}

	//=======================================================================
	//
	// Drawing
	//
	//=======================================================================

	static Color StateColor(int st)
	{
		switch (st)
		{
		case KS_BOUND:  return VKB_Gfx.KeyBound();
		case KS_CUSTOM: return VKB_Gfx.KeyCustom();
		case KS_MULTI:  return VKB_Gfx.KeyMulti();
		case KS_DEAD:   return VKB_Gfx.KeyDead();
		}
		return VKB_Gfx.KeyFree();
	}

	static String ViewLabel(int view)
	{
		switch (view)
		{
		case 1:  return StringTable.Localize("$VKB_VIEW_DOUBLE");
		case 2:  return StringTable.Localize("$VKB_VIEW_MAP");
		}
		return StringTable.Localize("$VKB_VIEW_GAME");
	}

	static String LayoutLabel(int layout)
	{
		switch (layout)
		{
		case 1: return "75%";
		case 2: return "60%";
		}
		return "100%";
	}

	override void Drawer()
	{
		double now = MSTimeF();
		double dt = clamp((now - mLastTime) / 1000.0, 0.0, 0.1);
		mLastTime = now;
		double intro = VKB_Gfx.EaseOut((now - mOpenTime) / 350.0);

		DoLayout();
		mHits.Clear();

		double sw = Screen.GetWidth();
		double sh = Screen.GetHeight();
		VKB_Gfx.Fill(0, 0, sw, sh, VKB_Gfx.PanelColor(), 0.80 * intro + 0.1);

		// Title and summary
		VKB_Gfx.Text(StringTable.Localize("$VKB_TITLE"), mMargin, mTitleY, Font.CR_WHITE, mTitleScale);
		String status = String.Format(StringTable.Localize("$VKB_STATUS"), mUsedKeys, mMultiKeys, LayoutLabel(mLayout));
		VKB_Gfx.Text(status, mMargin, mStatusY, Font.CR_GRAY, mSmallScale);

		DrawToolbar();
		DrawKeys(dt, intro);
		DrawLegend();
		DrawInfo();
		DrawFooter();

		Super.Drawer();
	}

	private void DrawToolbar()
	{
		double sw = Screen.GetWidth();
		double y = mToolbarY;
		double h = mToolbarH;
		double pad = h * 0.6;

		// Keyboard sizes, left
		double x = mMargin;
		for (int i = 0; i < 3; i++)
		{
			String label = LayoutLabel(i);
			double w = VKB_Gfx.TextWidth(label, mTextScale) + pad * 2;
			VKB_Gfx.Button(label, x, y, w, h, mTextScale, mHoverBtn == BTN_LAYOUT + i, mLayout == i);
			mHits.Add(BTN_LAYOUT + i, x, y, w, h);
			x += w + h * 0.15;
		}

		// Binding sets, right
		double total = 0;
		for (int i = 0; i < VKB_Catalog.NUM_SETS; i++)
		{
			total += VKB_Gfx.TextWidth(ViewLabel(i), mTextScale) + pad * 2 + h * 0.15;
		}
		x = sw - mMargin - total + h * 0.15;
		for (int i = 0; i < VKB_Catalog.NUM_SETS; i++)
		{
			String label = ViewLabel(i);
			double w = VKB_Gfx.TextWidth(label, mTextScale) + pad * 2;
			VKB_Gfx.Button(label, x, y, w, h, mTextScale, mHoverBtn == BTN_VIEW + i, mView == i);
			mHits.Add(BTN_VIEW + i, x, y, w, h);
			x += w + h * 0.15;
		}
	}

	private void DrawKeys(double dt, double intro)
	{
		double labelScale = VKB_Gfx.ScaleFor(mUnit * 0.27);
		double shortScale = VKB_Gfx.ScaleFor(mUnit * 0.19);
		double depth = max(2.0, mUnit * 0.07);

		for (int i = 0; i < mKeys.Size(); i++)
		{
			let k = mKeys[i];
			bool sel = i == mSel;

			k.mHover = VKB_Gfx.Approach(k.mHover, sel ? 1.0 : 0.0, dt, 16.0);

			// Entrance: keys rise in a wave from left to right.
			double wave = clamp(intro * 1.6 - (KeyCenterX(i) / max(1.0, mBoard.mWidth)) * 0.6, 0.0, 1.0);
			double appear = VKB_Gfx.EaseOut(wave);
			if (appear <= 0) continue;

			double x = mKX[i];
			double w = mKW[i];
			double h = mKH[i];
			double lift = k.mHover * depth * 0.8;
			double y = mKY[i] + (1.0 - appear) * mUnit * 0.4 - lift;

			Color face = StateColor(mState[i]);

			// Side (darker) and top face give the keycap some depth.
			VKB_Gfx.Fill(x, y + depth + lift, w, h - depth, Color(255, 8, 9, 12), 0.6 * appear);
			VKB_Gfx.Fill(x, y, w, h - depth, face, appear);
			if (k.mHover > 0.01)
			{
				VKB_Gfx.Fill(x, y, w, h - depth, Color(255, 255, 255, 255), 0.12 * k.mHover * appear);
			}
			if (sel)
			{
				VKB_Gfx.Outline(x - 1, y - 1, w + 2, h - depth + 2, VKB_Gfx.Accent(), max(1, int(mUnit * 0.04)));
			}

			mHits.Add(BTN_KEY + i, x, mKY[i], w, h);

			// Key label, top left
			double inner = max(2.0, mUnit * 0.1);
			int labelColor = mState[i] == KS_DEAD ? Font.CR_DARKGRAY : Font.CR_WHITE;
			String label = VKB_Gfx.Fit(StringTable.Localize(k.mLabel), w - inner * 2, labelScale);
			VKB_Gfx.Text(label, x + inner, y + inner * 0.6, labelColor, labelScale, appear);

			// What it does, bottom
			if (mShort[i].Length() > 0)
			{
				String s = VKB_Gfx.Fit(mShort[i], w - inner * 2, shortScale);
				double sy = y + h - depth - inner * 0.5 - VKB_Gfx.TextHeight(shortScale);
				VKB_Gfx.Text(s, x + inner, sy, Font.CR_CREAM, shortScale, appear * 0.95);
			}
		}
	}

	private void DrawLegend()
	{
		double sw = Screen.GetWidth();
		double s = mSmallScale;
		double box = VKB_Gfx.TextHeight(s) * 0.8;
		double gap = box * 2.2;

		String l1 = StringTable.Localize("$VKB_LEGEND_BOUND");
		String l2 = StringTable.Localize("$VKB_LEGEND_CUSTOM");
		String l3 = StringTable.Localize("$VKB_LEGEND_MULTI");
		String l4 = StringTable.Localize("$VKB_LEGEND_FREE");

		double total = (box * 1.5) * 4 + gap * 3
			+ VKB_Gfx.TextWidth(l1, s) + VKB_Gfx.TextWidth(l2, s) + VKB_Gfx.TextWidth(l3, s) + VKB_Gfx.TextWidth(l4, s);
		double x = (sw - total) / 2;
		double y = mLegendY;
		double ty = y;
		double by = y + (VKB_Gfx.TextHeight(s) - box) / 2;

		x = LegendItem(x, by, ty, box, gap, VKB_Gfx.KeyBound(), l1, s);
		x = LegendItem(x, by, ty, box, gap, VKB_Gfx.KeyCustom(), l2, s);
		x = LegendItem(x, by, ty, box, gap, VKB_Gfx.KeyMulti(), l3, s);
		LegendItem(x, by, ty, box, gap, VKB_Gfx.KeyFree(), l4, s);
	}

	private double LegendItem(double x, double by, double ty, double box, double gap, Color c, String label, double s)
	{
		VKB_Gfx.Fill(x, by, box, box, c);
		x += box * 1.5;
		VKB_Gfx.Text(label, x, ty, Font.CR_GRAY, s);
		return x + VKB_Gfx.TextWidth(label, s) + gap;
	}

	private void DrawInfo()
	{
		double sw = Screen.GetWidth();
		double x = mMargin;
		double w = sw - mMargin * 2;
		double y = mInfoY;
		double h = mInfoH;
		double lineH = VKB_Gfx.TextHeight(mTextScale) * 1.25;
		double pad = lineH * 0.5;

		VKB_Gfx.Fill(x, y, w, h, Color(255, 26, 29, 37), 0.92);
		VKB_Gfx.Outline(x, y, w, h, VKB_Gfx.LineColor(), 1);

		double tx = x + pad;
		double ty = y + pad * 0.8;

		// A toolbar button under the pointer explains itself here.
		if (mHoverBtn >= BTN_LAYOUT && mHoverBtn < BTN_LAYOUT + 3)
		{
			String tip = StringTable.Localize(String.Format("$VKB_LAYOUT_TIP_%d", mHoverBtn - BTN_LAYOUT));
			DrawWrapped(tip, tx, ty, w - pad * 2, Font.CR_GRAY, mTextScale, 4);
			return;
		}
		if (mHoverBtn >= BTN_VIEW && mHoverBtn < BTN_VIEW + VKB_Catalog.NUM_SETS)
		{
			String tip = StringTable.Localize(String.Format("$VKB_VIEW_TIP_%d", mHoverBtn - BTN_VIEW));
			DrawWrapped(tip, tx, ty, w - pad * 2, Font.CR_GRAY, mTextScale, 4);
			return;
		}

		if (mSel < 0 || mSel >= mKeys.Size()) return;
		let k = mKeys[mSel];

		// Key name and what kind of key it is
		VKB_Gfx.Text(KeyLabel(k), tx, ty, Font.CR_WHITE, mTextScale);
		String kind;
		int kindColor = Font.CR_GRAY;
		if (!k.mBindable)
		{
			kind = StringTable.Localize(k.mCode == 1 ? "$VKB_ESC_RESERVED" : "$VKB_FN_HARDWARE");
		}
		else
		{
			switch (mState[mSel])
			{
			case KS_FREE:   kind = StringTable.Localize("$VKB_UNASSIGNED"); break;
			case KS_BOUND:  kind = StringTable.Localize("$VKB_SINGLE"); kindColor = Font.CR_GREEN; break;
			case KS_CUSTOM: kind = StringTable.Localize("$VKB_CUSTOM"); kindColor = Font.CR_GOLD; break;
			case KS_MULTI:  kind = StringTable.Localize("$VKB_MULTI"); kindColor = Font.CR_RED; break;
			}
		}
		double kx = tx + VKB_Gfx.TextWidth(KeyLabel(k), mTextScale) + pad;
		VKB_Gfx.Text(VKB_Gfx.Fit(kind, x + w - pad - kx, mSmallScale), kx,
			ty + (VKB_Gfx.TextHeight(mTextScale) - VKB_Gfx.TextHeight(mSmallScale)) / 2, kindColor, mSmallScale);

		if (!k.mBindable) return;
		ty += lineH * 1.1;

		// What the key does in each binding set; the current one first.
		for (int n = 0; n < VKB_Catalog.NUM_SETS; n++)
		{
			int bset = (mView + n) % VKB_Catalog.NUM_SETS;
			String binding = VKB_Catalog.GetBinding(bset, k.mCode);
			if (bset != mView && binding.Length() == 0) continue;

			Array<String> cmds;
			VKB_Catalog.SplitCommands(binding, cmds);
			String desc = "";
			for (int c = 0; c < cmds.Size(); c++)
			{
				if (c > 0) desc = desc .. "  +  ";
				desc = desc .. mCatalog.DescribeCommand(bset, cmds[c]);
			}
			if (desc.Length() == 0) desc = "—";

			String head = ViewLabel(bset) .. ":  ";
			int headColor = bset == mView ? Font.CR_LIGHTBLUE : Font.CR_DARKGRAY;
			VKB_Gfx.Text(head, tx, ty, headColor, mSmallScale);
			double hx = tx + VKB_Gfx.TextWidth(head, mSmallScale);
			VKB_Gfx.Text(VKB_Gfx.Fit(desc, x + w - pad - hx, mSmallScale), hx, ty,
				bset == mView ? Font.CR_WHITE : Font.CR_GRAY, mSmallScale);
			ty += VKB_Gfx.TextHeight(mSmallScale) * 1.3;
			if (ty > y + h - lineH) break;
		}

		VKB_Gfx.Text(StringTable.Localize("$VKB_CLICK_EDIT"), tx, y + h - pad * 0.6 - VKB_Gfx.TextHeight(mSmallScale),
			Font.CR_DARKGRAY, mSmallScale);
	}

	// Draws text wrapped to a width, up to maxLines lines.
	static void DrawWrapped(String text, double x, double y, double w, int cr, double scale, int maxLines)
	{
		let fnt = VKB_Gfx.TextFont();
		BrokenLines lines = fnt.BreakLines(text, int(w / scale));
		double lh = VKB_Gfx.TextHeight(scale) * 1.2;
		for (int i = 0; i < lines.Count() && i < maxLines; i++)
		{
			VKB_Gfx.Text(lines.StringAt(i), x, y + i * lh, cr, scale);
		}
	}

	private void DrawFooter()
	{
		double sw = Screen.GetWidth();
		double h = mFooterH;
		double y = mFooterY;
		double pad = h * 0.7;

		String done = StringTable.Localize("$VKB_DONE");
		double dw = max(VKB_Gfx.TextWidth(done, mTextScale) + pad * 2, h * 4);
		double dx = sw - mMargin - dw;
		VKB_Gfx.Button(done, dx, y, dw, h, mTextScale, mHoverBtn == BTN_DONE, false);
		mHits.Add(BTN_DONE, dx, y, dw, h);

		String list = StringTable.Localize("$VKB_LIST");
		double lw = VKB_Gfx.TextWidth(list, mTextScale) + pad * 2;
		VKB_Gfx.Button(list, mMargin, y, lw, h, mTextScale, mHoverBtn == BTN_LIST, false);
		mHits.Add(BTN_LIST, mMargin, y, lw, h);
	}
}
