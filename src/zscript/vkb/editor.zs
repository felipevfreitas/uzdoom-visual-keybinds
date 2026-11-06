//===========================================================================
//
// Visual Keybinds - key editor
//
// Opened from the keyboard screen for one key. Two tabs:
//   On this key  - what the key runs now
//   All actions  - every action, with search
// Pick an action, then:
//   Assign here      put it on this key (replaces what the key had)
//   Press a key...   put it on the next key or button pressed
//   Unbind           remove it from every key
//   Default          give it back its default keys
//   Clear key        remove everything from this key
// Every change applies right away, like the stock controls menu.
//
// Keyboard and gamepad:
//   Up / Down        choose an action
//   Left / Right, Tab, LB / RB   switch tab
//   type             search (switches to All actions)
//   Backspace        delete a search character
//   Enter / A        Assign here
//   Del              Unbind
//
//===========================================================================

class VKB_EditorMenu : GenericMenu
{
	enum EButtons
	{
		BTN_TAB = 10,       // + tab
		BTN_SEARCH = 20,
		BTN_ASSIGN = 30,
		BTN_CAPTURE,
		BTN_UNBIND,
		BTN_RESET,
		BTN_CLEAR,
		BTN_PREV = 40,
		BTN_NEXT,
		BTN_DONE,
		BTN_ROW = 1000      // + row index
	}

	VKB_Catalog mCatalog;
	int mKey;
	String mKeyLabel;
	int mView;

	int mTab;
	String mSearch;
	Array<VKB_Action> mRows;
	Array<bool> mRowOnKey;
	int mOnKeyCount;

	int mSel;
	int mTop;
	int mVisibleRows;
	int mHoverId;

	String mStatus;
	int mStatusColor;
	double mStatusTime;

	double mOpenTime;
	double mMouseX, mMouseY;

	VKB_HitList mHits;

	//=======================================================================
	//
	// Setup
	//
	//=======================================================================

	void Setup(VKB_Catalog catalog, int key, String keyLabel, int view)
	{
		mCatalog = catalog;
		mKey = key;
		mKeyLabel = keyLabel;
		mView = view;
		mHits = new("VKB_HitList");
		mSearch = "";
		mSel = 0;
		mTop = 0;
		mVisibleRows = 8;
		mHoverId = -1;
		mMouseX = -1;
		mMouseY = -1;
		mOpenTime = MSTimeF();

		// Start on the key's own actions, or on the full list if it's empty.
		mTab = 0;
		Rebuild();
		if (mRows.Size() == 0)
		{
			mTab = 1;
			Rebuild();
		}
	}

	// Rebuilds the list, keeping the same action selected when possible.
	void Rebuild()
	{
		String keepCmd = "";
		if (mSel >= 0 && mSel < mRows.Size()) keepCmd = mRows[mSel].mCommand;

		mRows.Clear();
		mRowOnKey.Clear();

		Array<String> onKey;
		VKB_Catalog.SplitCommands(VKB_Catalog.GetBinding(mView, mKey), onKey);
		mOnKeyCount = onKey.Size();

		if (mTab == 0)
		{
			for (int i = 0; i < onKey.Size(); i++)
			{
				let a = mCatalog.FindAction(mView, onKey[i]);
				if (a == null)
				{
					// A command typed in the console or added by a mod
					// without a menu entry.
					a = new("VKB_Action");
					a.mLabel = onKey[i];
					a.mCategory = StringTable.Localize("$VKB_CUSTOM_CAT");
					a.mCommand = onKey[i];
					a.mSet = mView;
					a.mSearch = onKey[i].MakeLower();
				}
				mRows.Push(a);
				mRowOnKey.Push(true);
			}
		}
		else
		{
			String needle = mSearch.MakeLower();
			needle.StripLeftRight();
			for (int i = 0; i < mCatalog.mActions.Size(); i++)
			{
				let a = mCatalog.mActions[i];
				if (!mCatalog.UsableIn(a, mView)) continue;
				if (needle.Length() > 0 && a.mSearch.IndexOf(needle) < 0)
				{
					String keys = VKB_Catalog.KeysText(mView, a.mCommand).MakeLower();
					if (keys.IndexOf(needle) < 0) continue;
				}
				mRows.Push(a);
				mRowOnKey.Push(CommandIn(a.mCommand, onKey));
			}
		}

		mSel = mRows.Size() > 0 ? 0 : -1;
		if (keepCmd.Length() > 0)
		{
			for (int i = 0; i < mRows.Size(); i++)
			{
				if (mRows[i].mCommand ~== keepCmd)
				{
					mSel = i;
					break;
				}
			}
		}
		ClampScroll();
	}

	static bool CommandIn(String cmd, Array<String> list)
	{
		for (int i = 0; i < list.Size(); i++)
		{
			if (list[i] ~== cmd) return true;
		}
		return false;
	}

	private void ClampScroll()
	{
		int count = mRows.Size();
		int vis = max(1, mVisibleRows);
		if (mSel >= 0)
		{
			if (mSel < mTop) mTop = mSel;
			if (mSel >= mTop + vis) mTop = mSel - vis + 1;
		}
		mTop = clamp(mTop, 0, max(0, count - vis));
	}

	private void SetTab(int tab)
	{
		tab = clamp(tab, 0, 1);
		if (tab == mTab) return;
		mTab = tab;
		mTop = 0;
		Rebuild();
		MenuSound("menu/change");
	}

	private VKB_Action Selected()
	{
		return mSel >= 0 && mSel < mRows.Size() ? mRows[mSel] : null;
	}

	private void SetStatus(String text, int cr)
	{
		mStatus = text;
		mStatusColor = cr;
		mStatusTime = MSTimeF();
	}

	//=======================================================================
	//
	// Changes
	//
	//=======================================================================

	private bool CanAssign()
	{
		let a = Selected();
		if (a == null) return false;
		String cur = VKB_Catalog.GetBinding(mView, mKey);
		return !(cur ~== a.mCommand);
	}

	private bool CanUnbind()
	{
		let a = Selected();
		return a != null && VKB_Catalog.KeysText(mView, a.mCommand).Length() > 0;
	}

	private bool CanReset()
	{
		let a = Selected();
		return a != null && (mCatalog.HasDefault(a, mView) || CanUnbind());
	}

	private bool CanClear()
	{
		return VKB_Catalog.GetBinding(mView, mKey).Length() > 0;
	}

	private void DoAssign()
	{
		if (!CanAssign()) { MenuSound("menu/invalid"); return; }
		let a = Selected();

		String before = VKB_Catalog.GetBinding(mView, mKey);
		VKB_Catalog.SetBinding(mView, mKey, a.mCommand);

		String msg = String.Format(StringTable.Localize("$VKB_MSG_ASSIGNED"), a.mLabel, mKeyLabel);
		if (before.Length() > 0)
		{
			msg = msg .. " " .. String.Format(StringTable.Localize("$VKB_MSG_REPLACED"), DescribeBinding(before));
		}
		SetStatus(msg, Font.CR_GREEN);
		MenuSound("menu/choose");
		Rebuild();
	}

	private void DoUnbind()
	{
		if (!CanUnbind()) { MenuSound("menu/invalid"); return; }
		let a = Selected();
		VKB_Catalog.UnbindCommand(mView, a.mCommand);
		SetStatus(String.Format(StringTable.Localize("$VKB_MSG_UNBOUND"), a.mLabel), Font.CR_GOLD);
		MenuSound("menu/choose");
		Rebuild();
	}

	private void DoReset()
	{
		if (!CanReset()) { MenuSound("menu/invalid"); return; }
		let a = Selected();
		mCatalog.ResetAction(a, mView);
		String keys = VKB_Catalog.KeysText(mView, a.mCommand);
		if (keys.Length() == 0) keys = StringTable.Localize("$VKB_NONE");
		SetStatus(String.Format(StringTable.Localize("$VKB_MSG_RESET"), a.mLabel, keys), Font.CR_GREEN);
		MenuSound("menu/choose");
		Rebuild();
	}

	private void DoClear()
	{
		if (!CanClear()) { MenuSound("menu/invalid"); return; }
		VKB_Catalog.SetBinding(mView, mKey, "");
		SetStatus(String.Format(StringTable.Localize("$VKB_MSG_CLEARED"), mKeyLabel), Font.CR_GOLD);
		MenuSound("menu/choose");
		Rebuild();
	}

	private void DoCapture()
	{
		let a = Selected();
		if (a == null) { MenuSound("menu/invalid"); return; }
		MenuSound("menu/choose");
		let cap = new("VKB_CaptureMenu");
		cap.Setup(self, a.mLabel);
		cap.ActivateMenu();
	}

	// Called by the capture screen.
	void OnCaptured(int key)
	{
		let a = Selected();
		if (a == null || key <= 0) return;

		String before = VKB_Catalog.GetBinding(mView, key);
		VKB_Catalog.SetBinding(mView, key, a.mCommand);

		String keyName = VKB_Catalog.KeyName(key);
		String msg = String.Format(StringTable.Localize("$VKB_MSG_CAPTURED"), a.mLabel, keyName);
		if (before.Length() > 0 && !(before ~== a.mCommand))
		{
			msg = msg .. " " .. String.Format(StringTable.Localize("$VKB_MSG_REPLACED"), DescribeBinding(before));
		}
		SetStatus(msg, Font.CR_GREEN);
		Rebuild();
	}

	void OnCaptureCancelled()
	{
		SetStatus(StringTable.Localize("$VKB_MSG_CANCELLED"), Font.CR_GRAY);
	}

	private String DescribeBinding(String binding)
	{
		Array<String> cmds;
		VKB_Catalog.SplitCommands(binding, cmds);
		String res = "";
		for (int i = 0; i < cmds.Size(); i++)
		{
			if (i > 0) res = res .. " + ";
			res = res .. mCatalog.DescribeCommand(mView, cmds[i]);
		}
		return res;
	}

	//=======================================================================
	//
	// Input
	//
	//=======================================================================

	override bool OnUIEvent(UIEvent ev)
	{
		switch (ev.type)
		{
		case UIEvent.Type_MouseMove:
		case UIEvent.Type_LButtonDown:
			mMouseX = ev.MouseX;
			mMouseY = ev.MouseY;
			mHoverId = mHits.At(mMouseX, mMouseY, true);
			break;

		case UIEvent.Type_WheelUp:
			mTop = max(0, mTop - 2);
			ClampScrollOnly();
			return true;

		case UIEvent.Type_WheelDown:
			mTop += 2;
			ClampScrollOnly();
			return true;

		case UIEvent.Type_KeyDown:
			if (ev.KeyChar == UIEvent.Key_Tab)
			{
				SetTab(1 - mTab);
				return true;
			}
			if (ev.KeyChar == UIEvent.Key_Del)
			{
				DoUnbind();
				return true;
			}
			break;

		case UIEvent.Type_Char:
			if (!ev.IsCtrl && !ev.IsAlt && ev.KeyChar >= 32)
			{
				mSearch.AppendCharacter(ev.KeyChar);
				if (mTab != 1) mTab = 1;
				mTop = 0;
				Rebuild();
				return true;
			}
			break;
		}
		return Super.OnUIEvent(ev);
	}

	private void ClampScrollOnly()
	{
		int vis = max(1, mVisibleRows);
		mTop = clamp(mTop, 0, max(0, mRows.Size() - vis));
	}

	override bool MouseEvent(int type, int x, int y)
	{
		if (type != MOUSE_Click) return true;

		int id = mHits.At(x, y);
		if (id < 0) return false;

		if (id >= BTN_ROW)
		{
			int row = id - BTN_ROW;
			if (row != mSel && row < mRows.Size())
			{
				mSel = row;
				MenuSound("menu/cursor");
			}
			return true;
		}

		switch (id)
		{
		case BTN_TAB:     SetTab(0); break;
		case BTN_TAB + 1: SetTab(1); break;
		case BTN_SEARCH:  SetTab(1); break;
		case BTN_ASSIGN:  DoAssign(); break;
		case BTN_CAPTURE: DoCapture(); break;
		case BTN_UNBIND:  DoUnbind(); break;
		case BTN_RESET:   DoReset(); break;
		case BTN_CLEAR:   DoClear(); break;
		case BTN_PREV:    mTop -= max(1, mVisibleRows); ClampScrollOnly(); break;
		case BTN_NEXT:    mTop += max(1, mVisibleRows); ClampScrollOnly(); break;
		case BTN_DONE:    MenuEvent(MKEY_Back, false); break;
		}
		return true;
	}

	override bool MenuEvent(int mkey, bool fromcontroller)
	{
		switch (mkey)
		{
		case MKEY_Up:
			if (mRows.Size() > 0)
			{
				mSel = mSel <= 0 ? mRows.Size() - 1 : mSel - 1;
				ClampScroll();
				MenuSound("menu/cursor");
			}
			return true;

		case MKEY_Down:
			if (mRows.Size() > 0)
			{
				mSel = mSel >= mRows.Size() - 1 ? 0 : mSel + 1;
				ClampScroll();
				MenuSound("menu/cursor");
			}
			return true;

		case MKEY_Left:
			SetTab(0);
			return true;

		case MKEY_Right:
			SetTab(1);
			return true;

		case MKEY_PageUp:
			if (fromcontroller) { SetTab(0); return true; }
			if (mRows.Size() > 0)
			{
				mSel = max(0, mSel - max(1, mVisibleRows));
				ClampScroll();
			}
			return true;

		case MKEY_PageDown:
			if (fromcontroller) { SetTab(1); return true; }
			if (mRows.Size() > 0)
			{
				mSel = min(mRows.Size() - 1, mSel + max(1, mVisibleRows));
				ClampScroll();
			}
			return true;

		case MKEY_Enter:
			DoAssign();
			return true;

		case MKEY_Clear:
			// Backspace edits the search; on a gamepad (X) it unbinds.
			if (fromcontroller && mSearch.Length() == 0)
			{
				DoUnbind();
			}
			else if (mSearch.Length() > 0)
			{
				mSearch.DeleteLastCharacter();
				mTop = 0;
				Rebuild();
			}
			return true;
		}
		return Super.MenuEvent(mkey, fromcontroller);
	}

	//=======================================================================
	//
	// Drawing
	//
	//=======================================================================

	override void Drawer()
	{
		double sw = Screen.GetWidth();
		double sh = Screen.GetHeight();
		double now = MSTimeF();
		double intro = VKB_Gfx.EaseOut((now - mOpenTime) / 250.0);

		mHits.Clear();

		double margin = max(8.0, min(sw, sh) * 0.035);
		double titleScale = VKB_Gfx.ScaleFor(sh * 0.042);
		double textScale = VKB_Gfx.ScaleFor(sh * 0.026);
		double smallScale = VKB_Gfx.ScaleFor(sh * 0.021);
		double lineH = VKB_Gfx.TextHeight(textScale);

		VKB_Gfx.Fill(0, 0, sw, sh, VKB_Gfx.PanelColor(), 0.95);

		// The panel slides in a little.
		double px = margin;
		double pw = sw - margin * 2;
		double y = margin + (1.0 - intro) * lineH;

		// Title: "Keyboard / W"
		String title = String.Format(StringTable.Localize("$VKB_EDIT_TITLE"), mKeyLabel);
		VKB_Gfx.Text(VKB_Gfx.Fit(title, pw, titleScale), px, y, Font.CR_WHITE, titleScale, intro);
		y += VKB_Gfx.TextHeight(titleScale) + lineH * 0.3;

		// What the key does now
		String current = VKB_Catalog.GetBinding(mView, mKey);
		String now1 = VKB_KeyboardMenu.ViewLabel(mView) .. ":  ";
		VKB_Gfx.Text(now1, px, y, Font.CR_LIGHTBLUE, smallScale);
		String curText = current.Length() > 0 ? DescribeBinding(current) : StringTable.Localize("$VKB_UNASSIGNED");
		double cx = px + VKB_Gfx.TextWidth(now1, smallScale);
		VKB_Gfx.Text(VKB_Gfx.Fit(curText, px + pw - cx, smallScale), cx, y,
			current.Length() > 0 ? Font.CR_WHITE : Font.CR_DARKGRAY, smallScale);
		y += VKB_Gfx.TextHeight(smallScale) + lineH * 0.8;

		// Tabs
		double tabH = lineH * 1.7;
		double tx = px;
		for (int t = 0; t < 2; t++)
		{
			String label = t == 0
				? String.Format(StringTable.Localize("$VKB_ON_KEY"), mOnKeyCount)
				: StringTable.Localize("$VKB_ALL");
			double w = VKB_Gfx.TextWidth(label, textScale) + tabH * 1.2;
			VKB_Gfx.Button(label, tx, y, w, tabH, textScale, mHoverId == BTN_TAB + t, mTab == t);
			mHits.Add(BTN_TAB + t, tx, y, w, tabH);
			tx += w + tabH * 0.15;
		}

		// Search box, right of the tabs
		double sx = tx + tabH * 0.4;
		double sWidth = px + pw - sx;
		if (sWidth > lineH * 6)
		{
			bool active = mTab == 1;
			VKB_Gfx.Fill(sx, y, sWidth, tabH, Color(255, 10, 11, 15), 0.95);
			VKB_Gfx.Outline(sx, y, sWidth, tabH, active ? VKB_Gfx.Accent() : VKB_Gfx.LineColor(), 1);
			double ty = y + (tabH - lineH) / 2;
			double inner = tabH * 0.4;
			if (mSearch.Length() > 0)
			{
				String shown = mSearch;
				// Keep the end of long searches visible.
				while (shown.Length() > 1 && VKB_Gfx.TextWidth(shown, textScale) > sWidth - inner * 3)
				{
					shown = shown.Mid(1);
				}
				VKB_Gfx.Text(shown, sx + inner, ty, Font.CR_WHITE, textScale);
				if (active && (MenuTime() % 16) < 8)
				{
					VKB_Gfx.Text("_", sx + inner + VKB_Gfx.TextWidth(shown, textScale), ty, Font.CR_WHITE, textScale);
				}
			}
			else
			{
				String hint = VKB_Gfx.Fit(StringTable.Localize("$VKB_SEARCH"), sWidth - inner * 2, textScale);
				VKB_Gfx.Text(hint, sx + inner, ty, Font.CR_DARKGRAY, textScale);
			}
			mHits.Add(BTN_SEARCH, sx, y, sWidth, tabH);
		}
		y += tabH + lineH * 0.5;

		// Bottom part, laid out from the bottom up
		double footerH = lineH * 1.8;
		double footerY = sh - margin - footerH;
		double btnH = lineH * 1.9;
		double btnY = footerY - lineH * 0.6 - btnH;
		double tipY = btnY - lineH * 1.4;
		double detailY = tipY - lineH * 1.4;
		double listTop = y;
		double listBottom = detailY - lineH * 0.5;

		DrawList(px, listTop, pw, listBottom - listTop, textScale, smallScale);
		DrawDetail(px, detailY, pw, textScale);
		DrawTip(px, tipY, pw, smallScale);
		DrawButtons(px, btnY, pw, btnH, textScale);
		DrawFooter(px, footerY, pw, footerH, textScale, smallScale);

		Super.Drawer();
	}

	private void DrawList(double x, double y, double w, double h, double textScale, double smallScale)
	{
		double rowH = VKB_Gfx.TextHeight(textScale) * 1.7;
		mVisibleRows = max(1, int(h / rowH));
		ClampScrollOnly();

		VKB_Gfx.Fill(x, y, w, h, Color(255, 22, 25, 32), 0.9);
		VKB_Gfx.Outline(x, y, w, h, VKB_Gfx.LineColor(), 1);

		if (mRows.Size() == 0)
		{
			String empty = StringTable.Localize(mTab == 0 ? "$VKB_NO_BINDINGS" : "$VKB_NO_RESULTS");
			VKB_Gfx.TextCentered(empty, x + w / 2, y + h / 2 - VKB_Gfx.TextHeight(textScale) / 2, Font.CR_DARKGRAY, textScale);
			return;
		}

		double pad = rowH * 0.35;
		double ty = y;
		for (int i = mTop; i < mRows.Size() && i < mTop + mVisibleRows; i++)
		{
			let a = mRows[i];
			bool sel = i == mSel;
			bool hover = mHoverId == BTN_ROW + i;

			if (sel) VKB_Gfx.Fill(x + 1, ty, w - 2, rowH, VKB_Gfx.ButtonActive(), 0.9);
			else if (hover) VKB_Gfx.Fill(x + 1, ty, w - 2, rowH, VKB_Gfx.ButtonHover(), 0.7);
			else if ((i % 2) == 1) VKB_Gfx.Fill(x + 1, ty, w - 2, rowH, Color(255, 255, 255, 255), 0.025);

			if (sel) VKB_Gfx.Fill(x + 1, ty, max(2.0, rowH * 0.08), rowH, VKB_Gfx.Accent());

			// Green mark: this action is on the key being edited.
			double mark = rowH * 0.22;
			if (mRowOnKey[i])
			{
				VKB_Gfx.Fill(x + pad, ty + (rowH - mark) / 2, mark, mark, VKB_Gfx.KeyBound());
			}

			double textY = ty + (rowH - VKB_Gfx.TextHeight(textScale)) / 2;
			double labelX = x + pad + mark * 2;

			// Keys, right aligned
			String keys = VKB_Catalog.KeysText(mView, a.mCommand);
			if (keys.Length() == 0) keys = "—";
			double keysW = min(VKB_Gfx.TextWidth(keys, textScale), w * 0.32);
			String keysShown = VKB_Gfx.Fit(keys, keysW + 1, textScale);
			VKB_Gfx.TextRight(keysShown, x + w - pad, textY, keys == "—" ? Font.CR_DARKGRAY : Font.CR_GOLD, textScale);

			// Label and category
			double room = x + w - pad - keysW - pad - labelX;
			String label = VKB_Gfx.Fit(a.mLabel, room * 0.62, textScale);
			VKB_Gfx.Text(label, labelX, textY, Font.CR_WHITE, textScale);
			double catX = labelX + VKB_Gfx.TextWidth(label, textScale) + pad;
			String cat = VKB_Gfx.Fit(a.mCategory, x + w - pad - keysW - pad - catX, smallScale);
			VKB_Gfx.Text(cat, catX, ty + (rowH - VKB_Gfx.TextHeight(smallScale)) / 2, Font.CR_DARKGRAY, smallScale);

			mHits.Add(BTN_ROW + i, x, ty, w, rowH);
			ty += rowH;
		}

		// Scroll bar
		if (mRows.Size() > mVisibleRows)
		{
			double barW = max(2.0, rowH * 0.12);
			double frac = double(mVisibleRows) / mRows.Size();
			double pos = double(mTop) / mRows.Size();
			VKB_Gfx.Fill(x + w - barW - 1, y + h * pos, barW, max(barW * 2, h * frac), VKB_Gfx.LineColor());
		}
	}

	private void DrawDetail(double x, double y, double w, double textScale)
	{
		let a = Selected();
		if (a == null)
		{
			VKB_Gfx.Text(VKB_Gfx.Fit(StringTable.Localize("$VKB_SELECT"), w, textScale), x, y, Font.CR_GRAY, textScale);
			return;
		}
		String keys = VKB_Catalog.KeysText(mView, a.mCommand);
		if (keys.Length() == 0) keys = StringTable.Localize("$VKB_NONE");
		String line = String.Format(StringTable.Localize("$VKB_SELECTED"), a.mLabel, keys);
		VKB_Gfx.Text(VKB_Gfx.Fit(line, w, textScale), x, y, Font.CR_WHITE, textScale);
	}

	// Explains the button under the pointer; otherwise shows the last change.
	private void DrawTip(double x, double y, double w, double scale)
	{
		String tip = "";
		switch (mHoverId)
		{
		case BTN_ASSIGN:  tip = String.Format(StringTable.Localize("$VKB_ASSIGN_TIP"), mKeyLabel); break;
		case BTN_CAPTURE: tip = StringTable.Localize("$VKB_CAPTURE_TIP"); break;
		case BTN_UNBIND:  tip = StringTable.Localize("$VKB_UNBIND_TIP"); break;
		case BTN_RESET:   tip = StringTable.Localize("$VKB_RESET_TIP"); break;
		case BTN_CLEAR:   tip = String.Format(StringTable.Localize("$VKB_CLEAR_TIP"), mKeyLabel); break;
		}
		if (tip.Length() > 0)
		{
			VKB_Gfx.Text(VKB_Gfx.Fit(tip, w, scale), x, y, Font.CR_GRAY, scale);
			return;
		}

		if (mStatus.Length() > 0)
		{
			double age = (MSTimeF() - mStatusTime) / 1000.0;
			double alpha = age < 6.0 ? 1.0 : clamp(1.0 - (age - 6.0), 0.0, 1.0);
			VKB_Gfx.Text(VKB_Gfx.Fit(mStatus, w, scale), x, y, mStatusColor, scale, alpha);
		}
	}

	private void DrawButtons(double x, double y, double w, double h, double textScale)
	{
		static const int ids[] = { BTN_ASSIGN, BTN_CAPTURE, BTN_UNBIND, BTN_RESET, BTN_CLEAR };
		static const String labels[] = { "$VKB_ASSIGN", "$VKB_CAPTURE", "$VKB_UNBIND", "$VKB_RESET", "$VKB_CLEAR" };

		double gap = h * 0.2;
		double bw = (w - gap * 4) / 5;
		for (int i = 0; i < 5; i++)
		{
			int id = ids[i];
			bool enabled;
			switch (id)
			{
			case BTN_ASSIGN:  enabled = CanAssign(); break;
			case BTN_CAPTURE: enabled = Selected() != null; break;
			case BTN_UNBIND:  enabled = CanUnbind(); break;
			case BTN_RESET:   enabled = CanReset(); break;
			default:          enabled = CanClear(); break;
			}
			double bx = x + i * (bw + gap);
			VKB_Gfx.Button(StringTable.Localize(labels[i]), bx, y, bw, h, textScale, mHoverId == id, false, enabled);
			mHits.Add(id, bx, y, bw, h, enabled);
		}
	}

	private void DrawFooter(double x, double y, double w, double h, double textScale, double smallScale)
	{
		// Page info and arrows, left
		int vis = max(1, mVisibleRows);
		int pages = max(1, (mRows.Size() + vis - 1) / vis);
		int page = min(pages, mTop / vis + 1);
		String info = String.Format(StringTable.Localize("$VKB_PAGE"), page, pages, mRows.Size());

		double aw = h * 1.4;
		bool canPrev = mTop > 0;
		bool canNext = mTop + vis < mRows.Size();
		VKB_Gfx.Button("◀", x, y, aw, h, textScale, mHoverId == BTN_PREV, false, canPrev);
		mHits.Add(BTN_PREV, x, y, aw, h, canPrev);
		VKB_Gfx.Button("▶", x + aw + h * 0.15, y, aw, h, textScale, mHoverId == BTN_NEXT, false, canNext);
		mHits.Add(BTN_NEXT, x + aw + h * 0.15, y, aw, h, canNext);
		VKB_Gfx.Text(info, x + aw * 2 + h * 0.6, y + (h - VKB_Gfx.TextHeight(smallScale)) / 2, Font.CR_GRAY, smallScale);

		// Done, right
		String done = StringTable.Localize("$VKB_DONE");
		double dw = max(VKB_Gfx.TextWidth(done, textScale) + h * 1.4, h * 4);
		VKB_Gfx.Button(done, x + w - dw, y, dw, h, textScale, mHoverId == BTN_DONE, false);
		mHits.Add(BTN_DONE, x + w - dw, y, dw, h);
	}
}

//===========================================================================
//
// Waits for one key or mouse button, like the stock controls menu.
//
//===========================================================================

class VKB_CaptureMenu : Menu
{
	VKB_EditorMenu mEditor;
	String mActionLabel;
	double mOpenTime;

	void Setup(VKB_EditorMenu editor, String actionLabel)
	{
		Init(editor);
		mEditor = editor;
		mActionLabel = actionLabel;
		mOpenTime = MSTimeF();
		menuactive = Menu.WaitKey;  // receive raw keys, as the stock menu does
	}

	override bool TranslateKeyboardEvents()
	{
		return false;
	}

	override bool OnInputEvent(InputEvent ev)
	{
		if (ev.type != InputEvent.Type_KeyDown) return false;

		int key = ev.KeyScan;

		// The click that opened this screen can arrive as a raw button too.
		if (key == InputEvent.KEY_MOUSE1 && MSTimeF() - mOpenTime < 200) return true;

		menuactive = Menu.On;
		Close();
		if (key == InputEvent.KEY_ESCAPE || key == InputEvent.KEY_JOY2)
		{
			mEditor.OnCaptureCancelled();
			MenuSound("menu/backup");
		}
		else
		{
			mEditor.OnCaptured(key);
			MenuSound("menu/choose");
		}
		return true;
	}

	override void Drawer()
	{
		mEditor.Drawer();

		double sw = Screen.GetWidth();
		double sh = Screen.GetHeight();
		double t = VKB_Gfx.EaseOut((MSTimeF() - mOpenTime) / 200.0);

		VKB_Gfx.Fill(0, 0, sw, sh, Color(255, 0, 0, 0), 0.6 * t);

		double titleScale = VKB_Gfx.ScaleFor(sh * 0.045);
		double textScale = VKB_Gfx.ScaleFor(sh * 0.026);
		double smallScale = VKB_Gfx.ScaleFor(sh * 0.021);
		double lineH = VKB_Gfx.TextHeight(textScale);

		double w = min(sw * 0.8, lineH * 34);
		double h = lineH * 7.5;
		double x = (sw - w) / 2;
		double y = (sh - h) / 2 + (1.0 - t) * lineH;

		// Border pulses while waiting.
		double pulse = 0.5 + 0.5 * sin(MSTimeF() * 0.36);
		VKB_Gfx.Fill(x, y, w, h, VKB_Gfx.PanelColor(), 0.97 * t);
		VKB_Gfx.Outline(x, y, w, h, VKB_Gfx.Accent(), max(1, int(lineH * 0.08 * (1.0 + pulse))));

		double cx = x + w / 2;
		double ty = y + lineH * 1.0;
		VKB_Gfx.TextCentered(StringTable.Localize("$VKB_CAP_TITLE"), cx, ty, Font.CR_WHITE, titleScale, t);
		ty += VKB_Gfx.TextHeight(titleScale) + lineH * 0.6;
		String forWhat = String.Format(StringTable.Localize("$VKB_CAP_FOR"), mActionLabel);
		VKB_Gfx.TextCentered(VKB_Gfx.Fit(forWhat, w - lineH * 2, textScale), cx, ty, Font.CR_GOLD, textScale, t);
		ty += lineH * 1.8;
		VKB_Gfx.TextCentered(VKB_Gfx.Fit(StringTable.Localize("$VKB_CAP_CANCEL"), w - lineH * 2, smallScale), cx, ty,
			Font.CR_GRAY, smallScale, t);
	}
}
