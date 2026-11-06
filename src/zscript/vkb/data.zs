//===========================================================================
//
// Visual Keybinds - data
//
// VKB_Board    the keys of one keyboard layout
// VKB_Action   one bindable action from the controls menus
// VKB_Catalog  every action the game and loaded mods offer, plus the
//              default bindings, used by both screens
//
// Binding sets: the engine keeps three separate tables of key bindings.
//   0 = game (normal), 1 = double tap, 2 = automap
//
//===========================================================================

class VKB_Key : Object ui
{
	int mCode;          // engine key code, 0 for keys that can't be bound
	double mX, mY, mW, mH;
	String mLabel;
	bool mBindable;
	double mHover;      // 0..1, animated
}

class VKB_Board : Object ui
{
	Array<VKB_Key> mKeys;
	double mWidth;
	double mHeight;

	void Add(int code, double x, double y, double w, double h, String label, bool bindable)
	{
		let k = new("VKB_Key");
		k.mCode = code;
		k.mX = x;
		k.mY = y;
		k.mW = w;
		k.mH = h;
		k.mLabel = label;
		if (label == "#BACKSLASH")
		{
			// A backslash can't be written inside a ZScript string literal.
			k.mLabel = "";
			k.mLabel.AppendCharacter(92);
		}
		// Escape always opens the menu, so the engine never runs a binding on it.
		k.mBindable = bindable && code != 1 && code != 0;
		mKeys.Push(k);
	}

	static VKB_Board Create(int layout)
	{
		let b = new("VKB_Board");
		switch (layout)
		{
		case 1:  VKB_Layouts.TKL75(b); break;
		case 2:  VKB_Layouts.Compact60(b); break;
		default: VKB_Layouts.Full(b); break;
		}
		return b;
	}

	static VKB_Board CreateMouse()
	{
		let b = new("VKB_Board");
		VKB_Layouts.Mouse(b);
		return b;
	}
}

class VKB_Action : Object ui
{
	String mLabel;      // localized
	String mCategory;   // localized title of the menu it came from
	String mCommand;
	int mSet;           // binding set, see top of file
	String mSearch;     // lowercase text used by the search box
}

class VKB_Catalog : Object ui
{
	const NUM_KEYS = 0x1CB;
	const NUM_SETS = 3;

	Array<VKB_Action> mActions;

	// Default bindings: index = set * NUM_KEYS + key
	Array<String> mDefaults;

	// Lowercase key name -> key code, for reading the default binding files.
	Array<String> mKeyNames;

	//=======================================================================
	//
	// Binding sets
	//
	//=======================================================================

	static String GetBinding(int bset, int key)
	{
		if (key <= 0 || key >= NUM_KEYS) return "";
		switch (bset)
		{
		case 1:  return DoubleBindings.GetBinding(key);
		case 2:  return AutomapBindings.GetBinding(key);
		default: return Bindings.GetBinding(key);
		}
	}

	static void SetBinding(int bset, int key, String cmd)
	{
		if (key <= 0 || key >= NUM_KEYS) return;
		switch (bset)
		{
		case 1:  DoubleBindings.SetBind(key, cmd); break;
		case 2:  AutomapBindings.SetBind(key, cmd); break;
		default: Bindings.SetBind(key, cmd); break;
		}
	}

	static void UnbindCommand(int bset, String cmd)
	{
		switch (bset)
		{
		case 1:  DoubleBindings.UnbindACommand(cmd); break;
		case 2:  AutomapBindings.UnbindACommand(cmd); break;
		default: Bindings.UnbindACommand(cmd); break;
		}
	}

	static void KeysForCommand(int bset, String cmd, out Array<int> keys)
	{
		keys.Clear();
		switch (bset)
		{
		case 1:  DoubleBindings.GetAllKeysForCommand(keys, cmd); break;
		case 2:  AutomapBindings.GetAllKeysForCommand(keys, cmd); break;
		default: Bindings.GetAllKeysForCommand(keys, cmd); break;
		}
	}

	static String KeyName(int key)
	{
		if (key <= 0) return "";
		return KeyBindings.NameKeys(key, 0, false);
	}

	static String KeysText(int bset, String cmd)
	{
		Array<int> keys;
		KeysForCommand(bset, cmd, keys);
		return KeyBindings.NameAllKeys(keys, false);
	}

	// A binding can hold several commands separated by ';'.
	static void SplitCommands(String binding, out Array<String> cmds)
	{
		cmds.Clear();
		Array<String> parts;
		binding.Split(parts, ";", TOK_SKIPEMPTY);
		for (int i = 0; i < parts.Size(); i++)
		{
			String p = parts[i];
			p.StripLeftRight();
			if (p.Length() > 0) cmds.Push(p);
		}
	}

	//=======================================================================
	//
	// Building the catalog
	//
	//=======================================================================

	static VKB_Catalog Create()
	{
		let c = new("VKB_Catalog");
		c.Build();
		return c;
	}

	void Build()
	{
		mActions.Clear();

		Array<Name> visited;
		// The stock controls menus first, so their names win over copies.
		Walk('CustomizeControls', visited, 0);
		// Then everything reachable from the Options menu: mods usually put
		// their own key settings in a submenu there.
		Walk('OptionsMenu', visited, 0);

		BuildKeyNames();
		BuildDefaults();
	}

	private void Walk(Name menuName, out Array<Name> visited, int depth)
	{
		if (depth > 8) return;
		for (int i = 0; i < visited.Size(); i++)
		{
			if (visited[i] == menuName) return;
		}
		visited.Push(menuName);

		let desc = OptionMenuDescriptor(MenuDescriptor.GetDescriptor(menuName));
		if (desc == null) return;

		String category = StringTable.Localize(desc.mTitle);

		for (int i = 0; i < desc.mItems.Size(); i++)
		{
			let item = desc.mItems[i];
			if (item == null) continue;

			let ctrl = OptionMenuItemControlBase(item);
			if (ctrl != null)
			{
				int bset = 0;
				if (item is "OptionMenuItemMapControl") bset = 2;
				else if (item is "OptionMenuItemDoubleTapControl") bset = 1;

				Name cmdName = item.GetAction();
				String cmd = cmdName;
				AddAction(StringTable.Localize(item.mLabel), category, cmd, bset);
				continue;
			}

			// Follow plain submenus. Commands and other items also derive
			// from the submenu item, so check the exact class.
			if (item.GetClass() == "OptionMenuItemSubmenu" || item.GetClass() == "OptionMenuItemLabeledSubmenu")
			{
				Name sub = item.GetAction();
				Walk(sub, visited, depth + 1);
			}
		}
	}

	private void AddAction(String label, String category, String cmd, int bset)
	{
		if (cmd.Length() == 0) return;
		for (int i = 0; i < mActions.Size(); i++)
		{
			if (mActions[i].mSet == bset && mActions[i].mCommand ~== cmd) return;
		}

		let a = new("VKB_Action");
		a.mLabel = label;
		a.mCategory = category;
		a.mCommand = cmd;
		a.mSet = bset;
		a.mSearch = (label .. " " .. category .. " " .. cmd).MakeLower();
		mActions.Push(a);
	}

	// Actions offered when editing a binding set. The double tap set has no
	// actions of its own in most games, so it also offers the normal ones.
	bool UsableIn(VKB_Action a, int bset)
	{
		if (a.mSet == bset) return true;
		if (bset == 1 && a.mSet == 0) return true;
		return false;
	}

	VKB_Action FindAction(int bset, String cmd)
	{
		for (int i = 0; i < mActions.Size(); i++)
		{
			if (mActions[i].mSet == bset && mActions[i].mCommand ~== cmd) return mActions[i];
		}
		// Double tap bindings usually reuse normal commands.
		if (bset == 1)
		{
			for (int i = 0; i < mActions.Size(); i++)
			{
				if (mActions[i].mSet == 0 && mActions[i].mCommand ~== cmd) return mActions[i];
			}
		}
		return null;
	}

	// Readable name for a command: the action's label, or the raw command.
	String DescribeCommand(int bset, String cmd)
	{
		let a = FindAction(bset, cmd);
		return a != null ? a.mLabel : cmd;
	}

	//=======================================================================
	//
	// Default bindings
	//
	// Reads the same files the engine uses for "binddefaults": the common
	// bindings, the preset chosen in the controls menu, and DEFBINDS lumps
	// from the game and mods.
	//
	//=======================================================================

	private void BuildKeyNames()
	{
		mKeyNames.Clear();
		for (int k = 0; k < NUM_KEYS; k++)
		{
			String n = k > 0 ? KeyBindings.NameKeys(k, 0, false) : "";
			mKeyNames.Push(n.MakeLower());
		}
	}

	private int KeyFromName(String keyName)
	{
		String n = keyName.MakeLower();
		if (n.Length() > 1 && n.Left(1) == "#") return n.Mid(1).ToInt(10);

		if (n == "leftbracket") n = "[";
		else if (n == "rightbracket") n = "]";
		else if (n == "equals") n = "=";
		else if (n == "kp-equals") n = "kp=";
		else if (n == "semicolon") n = ";";
		else if (n == "colon") n = ":";

		for (int k = 1; k < mKeyNames.Size(); k++)
		{
			if (mKeyNames[k] == n) return k;
		}
		return 0;
	}

	String DefaultBinding(int bset, int key)
	{
		if (key <= 0 || key >= NUM_KEYS || bset < 0 || bset >= NUM_SETS) return "";
		return mDefaults[bset * NUM_KEYS + key];
	}

	private void BuildDefaults()
	{
		mDefaults.Clear();
		for (int i = 0; i < NUM_SETS * NUM_KEYS; i++) mDefaults.Push("");

		int lump = Wads.CheckNumForFullName("engine/commonbinds.txt");
		if (lump >= 0) ReadBindingLump(lump, true);

		int preset = 0;
		let cv = CVar.FindCVar('cl_defaultconfiguration');
		if (cv != null) preset = cv.GetInt();
		String baseFile = preset == 1 ? "engine/origbinds.txt" : (preset == 2 ? "engine/leftbinds.txt" : "engine/defbinds.txt");

		lump = -1;
		while ((lump = Wads.FindLumpFullName(baseFile, lump + 1)) >= 0)
		{
			ReadBindingLump(lump, true);
		}

		lump = -1;
		while ((lump = Wads.FindLump("DEFBINDS", lump + 1)) >= 0)
		{
			// Mod defaults never replace the engine's, same as in the engine.
			ReadBindingLump(lump, false);
		}
	}

	// Splits a binding file into words, keeping quoted text together and
	// dropping // comments.
	private static void Tokenize(String text, out Array<String> lines)
	{
		lines.Clear();

		// Control characters built from their codes rather than escapes.
		String lf = "";
		lf.AppendCharacter(10);
		String cr = "";
		cr.AppendCharacter(13);
		String tab = "";
		tab.AppendCharacter(9);

		Array<String> raw;
		text.Split(raw, lf, TOK_KEEPEMPTY);
		for (int i = 0; i < raw.Size(); i++)
		{
			String line = raw[i];
			line.Replace(cr, "");
			line.Replace(tab, " ");
			lines.Push(line);
		}
	}

	private static void LineWords(String line, out Array<String> words)
	{
		words.Clear();
		String cur = "";
		bool inQuote = false;
		bool hasWord = false;
		int len = line.Length();
		for (int i = 0; i < len; i++)
		{
			int c = line.ByteAt(i);
			if (!inQuote && c == 47 && i + 1 < len && line.ByteAt(i + 1) == 47) break; // "//"
			if (c == 34) // quote
			{
				inQuote = !inQuote;
				hasWord = true;
				continue;
			}
			if (!inQuote && c == 32)
			{
				if (hasWord) words.Push(cur);
				cur = "";
				hasWord = false;
				continue;
			}
			cur.AppendCharacter(c);
			hasWord = true;
		}
		if (hasWord) words.Push(cur);
	}

	private void ReadBindingLump(int lump, bool replace)
	{
		Array<String> lines;
		Tokenize(Wads.ReadLump(lump), lines);

		Array<String> words;
		for (int i = 0; i < lines.Size(); i++)
		{
			LineWords(lines[i], words);
			if (words.Size() == 0) continue;

			int bset = 0;
			int at = 0;
			String first = words[0].MakeLower();

			if (first == "unbind")
			{
				if (words.Size() >= 2 && replace)
				{
					int key = KeyFromName(words[1]);
					if (key > 0) mDefaults[key] = "";
				}
				continue;
			}
			if (first == "bind") at = 1;
			else if (first == "doublebind") { at = 1; bset = 1; }
			else if (first == "mapbind") { at = 1; bset = 2; }

			if (words.Size() < at + 2) continue;

			int key = KeyFromName(words[at]);
			if (key <= 0) continue;

			int idx = bset * NUM_KEYS + key;
			if (replace || mDefaults[idx].Length() == 0)
			{
				mDefaults[idx] = words[at + 1];
			}
		}
	}

	// Gives an action back its default keys. Keys that held something else
	// by default are left alone.
	void ResetAction(VKB_Action a, int bset)
	{
		UnbindCommand(bset, a.mCommand);
		for (int key = 1; key < NUM_KEYS; key++)
		{
			String def = DefaultBinding(bset, key);
			if (def.Length() > 0 && def ~== a.mCommand)
			{
				SetBinding(bset, key, a.mCommand);
			}
		}
	}

	bool HasDefault(VKB_Action a, int bset)
	{
		for (int key = 1; key < NUM_KEYS; key++)
		{
			String def = DefaultBinding(bset, key);
			if (def.Length() > 0 && def ~== a.mCommand) return true;
		}
		return false;
	}
}
