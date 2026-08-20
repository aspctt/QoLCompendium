import java.io.*;
import java.lang.reflect.*;
import java.util.*;

import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.KahluaTable;
import se.krka.kahlua.vm.KahluaThread;
import se.krka.kahlua.vm.LuaClosure;

/*
 * Headless test runner for the QoL Compendium.
 *
 * Boots the exact Kahlua VM that Project Zomboid ships, installs a stubbed game API,
 * loads the real mod source, and runs Lua specs against it. Every test gets a fresh
 * environment, so a mod's file-level locals cannot leak between tests.
 *
 * Usage: TestRunner <gameDir> <luaFile> [luaFile ...]
 *   Files load in the given order. Must run with the game directory as the working
 *   directory, because Kahlua resolves stdlib.lua relative to it.
 */
public class TestRunner {

	private static String gameDir;
	private static String modRoot;
	private static final List<String> loadFiles = new ArrayList<String>();
	private static List<String> moodleTypes = new ArrayList<String>();
	private static List<String> characterStats = new ArrayList<String>();
	private static List<String> characterTraits = new ArrayList<String>();
	private static List<String> proceduralNames = new ArrayList<String>();
	private static final Map<String, float[]> statBounds = new LinkedHashMap<String, float[]>();
	private static final Map<String, Object> sandboxDefaults = new LinkedHashMap<String, Object>();
	private static int translationFailures = 0;

	public static void main(String[] args) throws Exception {
		if (args.length < 3) {
			System.out.println("usage: TestRunner <gameDir> <modRoot> <luaFile> [luaFile ...]");
			System.exit(2);
		}
		gameDir = args[0];
		modRoot = new File(args[1]).getCanonicalPath();
		for (int i = 2; i < args.length; i++) loadFiles.add(args[i]);

		moodleTypes = readConstants("zombie.scripting.objects.MoodleType");
		System.out.println("MoodleType constants found in this build: " + moodleTypes.size());

		characterStats = readCharacterStats();
		System.out.println("CharacterStat constants found in this build: " + characterStats.size());

		characterTraits = readConstants("zombie.scripting.objects.CharacterTrait");
		System.out.println("CharacterTrait constants found in this build: " + characterTraits.size());

		proceduralNames = readProceduralNames();
		System.out.println("Loot tables found in this build: " + proceduralNames.size());

		int staticFailures = checkConstantUsage("MoodleType.", moodleTypes)
			+ checkConstantUsage("CharacterStat.", characterStats)
			+ checkConstantUsage("CharacterTrait.", characterTraits)
			+ checkItemScripts()
			+ checkSandboxOptions()
			+ checkTexturePaths()
			+ checkTextureFolders()
			+ checkTagPatches()
			+ checkExposedReturns()
			+ checkItemTypes()
			+ checkRecipeNames()
			+ checkTileDefs();

		// Discovery pass: load everything once just to learn the test names.
		List<String> names;
		try {
			names = discoverTests();
		} catch (Exception e) {
			System.out.println("FATAL  could not load test environment");
			System.out.println("       " + rootCause(e));
			System.exit(1);
			return;
		}

		System.out.println("Running " + names.size() + " test(s)");
		System.out.println();

		int failures = 0;
		for (int i = 0; i < names.size(); i++) {
			Result r = runSingle(i + 1);
			if (r.ok) {
				System.out.println("  PASS  " + r.name);
			} else {
				failures++;
				System.out.println("  FAIL  " + r.name);
				for (String line : r.error.split("\n")) System.out.println("        " + line);
			}
		}

		System.out.println();
		int total = failures + staticFailures + translationFailures;
		System.out.println(total == 0
			? "ALL " + names.size() + " TEST(S) PASSED"
			: total + " FAILURE(S)");
		System.exit(total == 0 ? 0 : 1);
	}

	/* ---------- environment ---------- */

	private static KahluaTable freshEnv(J2SEPlatform platform) {
		KahluaTable env = platform.newEnvironment();

		KahluaTable types = platform.newTable();
		KahluaTable list = platform.newTable();
		for (int i = 0; i < moodleTypes.size(); i++) {
			String n = moodleTypes.get(i);
			types.rawset(n, n);
			list.rawset(Double.valueOf(i + 1), n);
		}
		env.rawset("MoodleType", types);
		env.rawset("QOLC_MOODLE_TYPES", list);

		// Build 42 moved every named stat accessor onto CharacterStat, so the same
		// treatment applies: names come from the jar, and the real min/max travel with
		// them so the stub can clamp exactly like Stats.set does.
		KahluaTable stats = platform.newTable();
		KahluaTable bounds = platform.newTable();
		for (int i = 0; i < characterStats.size(); i++) {
			String n = characterStats.get(i);
			stats.rawset(n, n);
			float[] b = statBounds.get(n);
			if (b != null) {
				KahluaTable entry = platform.newTable();
				entry.rawset("Min", Double.valueOf(b[0]));
				entry.rawset("Max", Double.valueOf(b[1]));
				entry.rawset("Default", Double.valueOf(b[2]));
				bounds.rawset(n, entry);
			}
		}
		env.rawset("CharacterStat", stats);
		env.rawset("QOLC_STAT_BOUNDS", bounds);

		KahluaTable traits = platform.newTable();
		for (String n : characterTraits) traits.rawset(n, n);
		env.rawset("CharacterTrait", traits);

		KahluaTable defaults = platform.newTable();
		for (Map.Entry<String, Object> e : sandboxDefaults.entrySet()) {
			defaults.rawset(e.getKey(), e.getValue());
		}
		env.rawset("QOLC_SANDBOX_DEFAULTS", defaults);

		// Mods standing beside this one for this run, from the QOLC_MODS environment
		// variable. Some guards run at file scope and decide whether a feature installs
		// itself at all, so the only way to exercise them is to load the whole mod again
		// with a different mod list. See the second pass in run-tests.ps1.
		KahluaTable extraMods = platform.newTable();
		String mods = System.getenv("QOLC_MODS");
		if (mods != null && mods.trim().length() > 0) {
			String[] ids = mods.split(",");
			int n = 0;
			for (String id : ids) {
				if (id.trim().length() == 0) continue;
				extraMods.rawset(Double.valueOf(++n), id.trim());
			}
		}
		env.rawset("QOLC_EXTRA_MODS", extraMods);

		// Every item icon the mod ships, by the name an Icon= value would use. An Icon
		// naming a texture that does not exist draws nothing and reports nothing, which
		// is how the original literature mod ended up shipping five book icons that were
		// never there.
		KahluaTable textures = platform.newTable();
		File[] iconDirs = {
			new File(modRoot, "common/media/textures"),
			new File(modRoot, "42/media/textures")
		};
		for (File dir : iconDirs) {
			File[] files = dir.listFiles();
			if (files == null) continue;
			for (File f : files) {
				String n = f.getName();
				if (!n.startsWith("Item_") || !n.endsWith(".png")) continue;
				textures.rawset(n.substring(5, n.length() - 4), Boolean.TRUE);
			}
		}
		env.rawset("QOLC_ITEM_ICONS", textures);

		// Every loot table vanilla defines, so the stub builds its own from the real
		// names. A distribution naming a table that does not exist writes into nothing,
		// and the game skips it without a word, so the only way to catch a typo is for
		// the harness to know which names are real.
		KahluaTable procedural = platform.newTable();
		for (int i = 0; i < proceduralNames.size(); i++) {
			procedural.rawset(Double.valueOf(i + 1), proceduralNames.get(i));
		}
		env.rawset("QOLC_PROCEDURAL_NAMES", procedural);

		env.rawset("QOLC_GAME_DIR", gameDir);
		// Every script this mod ships, by file name. A few things live in a script rather
		// than in lua, and the only honest assertion about those is against what was
		// actually written. Kahlua has no io library to read them itself.
		KahluaTable scripts = platform.newTable();
		for (File dir : new File[] { new File(modRoot, "42/media/scripts"),
				new File(modRoot, "common/media/scripts") }) {
			File[] files = dir.listFiles();
			if (files == null) continue;
			for (File f : files) {
				if (!f.getName().endsWith(".txt")) continue;
				try {
					scripts.rawset(f.getName(), readAll(f));
				} catch (IOException e) {
					// A script that cannot be read fails the checks above on its own.
				}
			}
		}
		env.rawset("QOLC_MOD_SCRIPTS", scripts);
		return env;
	}

	private static KahluaThread load(J2SEPlatform platform, KahluaTable env) throws Exception {
		KahluaThread thread = new KahluaThread(System.out, platform, env);
		// PZ's Kahlua fork dereferences this when reporting a Lua error. Left null it
		// throws an NPE that hides the actual failure.
		thread.debugOwnerThread = Thread.currentThread();
		for (String path : loadFiles) {
			File f = new File(path);
			if (isTranslation(f)) {
				loadTranslation(platform, env, f);
				continue;
			}
			InputStream in = new FileInputStream(f);
			try {
				LuaClosure closure = LuaCompiler.loadis(in, f.getName(), env);
				thread.call(closure, new Object[0]);
			} finally {
				in.close();
			}
		}
		return thread;
	}

	private static boolean isTranslation(File f) {
		return f.getName().endsWith(".json") && f.getPath().replace('\\', '/').contains("/Translate/");
	}

	/**
	 * Build 42 translations are flat json, not lua. Keys such as "Base.SlingAFront" or
	 * "Hotbar 16" are perfectly legal there and would be a syntax error if compiled.
	 * Every file merges into one global Translations table, so a spec can look up any
	 * key without caring which file it came from.
	 */
	private static void loadTranslation(J2SEPlatform platform, KahluaTable env, File f) throws IOException {
		Object existing = env.rawget("Translations");
		KahluaTable table = (existing instanceof KahluaTable) ? (KahluaTable) existing : platform.newTable();
		int entries = 0;

		BufferedReader r = new BufferedReader(new InputStreamReader(new FileInputStream(f), "UTF-8"));
		String line;
		try {
			java.util.regex.Pattern entry =
				java.util.regex.Pattern.compile("^\\s*\"(.+?)\"\\s*:\\s*\"(.*)\"\\s*,?\\s*$");
			while ((line = r.readLine()) != null) {
				java.util.regex.Matcher m = entry.matcher(line);
				if (m.find()) {
					// The game runs every translation through String.format, so a bare
					// percent is an invalid conversion and the whole string fails to
					// render. Vanilla writes a literal percent as %%.
					//
					// %1 and %2 are the game's own positional arguments, substituted
					// before that happens, so they are not bare percents. Vanilla's
					// "XP Boost: +%1" is the example, and this check used to fail it.
					String value = m.group(2);
					if (value.replace("%%", "").replaceAll("%\\d", "").indexOf('%') >= 0) {
						System.out.println("  FAIL  unescaped % in translation \"" + m.group(1)
							+ "\"  (" + f.getName() + "), vanilla writes it as %%");
						translationFailures++;
					}
					table.rawset(m.group(1), value);
					entries++;
				}
			}
		} finally {
			r.close();
		}

		env.rawset("Translations", table);
		if (entries == 0) System.out.println("WARN   no entries parsed from " + f.getName());
	}

	private static List<String> discoverTests() throws Exception {
		J2SEPlatform platform = new J2SEPlatform();
		KahluaTable env = freshEnv(platform);
		load(platform, env);

		List<String> names = new ArrayList<String>();
		Object testsObj = env.rawget("Tests");
		if (!(testsObj instanceof KahluaTable)) return names;
		Object regObj = ((KahluaTable) testsObj).rawget("Registered");
		if (!(regObj instanceof KahluaTable)) return names;

		KahluaTable reg = (KahluaTable) regObj;
		for (int i = 1; i <= reg.len(); i++) {
			Object entry = reg.rawget(Double.valueOf(i));
			if (entry instanceof KahluaTable) {
				names.add(String.valueOf(((KahluaTable) entry).rawget("Name")));
			}
		}
		return names;
	}

	private static Result runSingle(int index) {
		Result r = new Result();
		r.name = "test #" + index;
		try {
			J2SEPlatform platform = new J2SEPlatform();
			KahluaTable env = freshEnv(platform);
			KahluaThread thread = load(platform, env);

			Object fn = env.rawget("RunSingleTest");
			if (fn == null) throw new IllegalStateException("RunSingleTest is not defined by the harness");
			thread.call(fn, new Object[] { Double.valueOf(index) });

			Object name = env.rawget("TEST_NAME");
			if (name != null) r.name = String.valueOf(name);
			r.ok = Boolean.TRUE.equals(env.rawget("TEST_OK"));
			Object err = env.rawget("TEST_ERROR");
			r.error = err == null ? "no error reported" : String.valueOf(err);
		} catch (Throwable t) {
			r.ok = false;
			r.error = rootCause(t);
		}
		return r;
	}

	/* ---------- static checks ---------- */

	/** Reads the MoodleType constant names straight out of the shipped jar. */
	/**
	 * The UPPER_SNAKE constants a class declares, read out of the installed jar. Build 42
	 * renamed whole families of these at once, and a retired one is nil at runtime rather
	 * than an error, so the mod source is checked against what this build really has.
	 */
	private static List<String> readConstants(String className) {
		List<String> names = new ArrayList<String>();
		try {
			// false = do not run static initialisers, which would need a live game
			Class<?> c = Class.forName(className, false, TestRunner.class.getClassLoader());
			for (Field f : c.getDeclaredFields()) {
				if (!Modifier.isStatic(f.getModifiers())) continue;
				if (!f.getName().matches("[A-Z][A-Z0-9_]*")) continue;
				names.add(f.getName());
			}
		} catch (Throwable t) {
			System.out.println("WARN   could not read " + className + " from the jar: " + t);
		}
		return names;
	}

	/**
	 * Reads the CharacterStat constants and their real bounds out of the shipped jar.
	 * Unlike MoodleType this one has to be initialised, because the constants are built
	 * by a static block calling register(id, min, max, default) rather than declared.
	 */
	private static List<String> readCharacterStats() {
		List<String> names = new ArrayList<String>();
		try {
			// true = run the static initialiser. It only fills a HashMap, so it works
			// without a live game.
			Class<?> c = Class.forName("zombie.characters.CharacterStat", true,
				TestRunner.class.getClassLoader());
			Method min = c.getMethod("getMinimumValue");
			Method max = c.getMethod("getMaximumValue");
			Method def = c.getMethod("getDefaultValue");

			for (Field f : c.getDeclaredFields()) {
				if (!Modifier.isStatic(f.getModifiers())) continue;
				if (!f.getType().equals(c)) continue;
				if (!f.getName().matches("[A-Z][A-Z0-9_]*")) continue;

				names.add(f.getName());
				Object v = f.get(null);
				if (v == null) continue;
				statBounds.put(f.getName(), new float[] {
					((Float) min.invoke(v)).floatValue(),
					((Float) max.invoke(v)).floatValue(),
					((Float) def.invoke(v)).floatValue()
				});
			}
		} catch (Throwable t) {
			System.out.println("WARN   could not read CharacterStat from the jar: " + t);
		}
		return names;
	}

	/**
	 * Scans every loaded mod file for <prefix>X references and verifies each one exists
	 * in the installed build. Catches build-41 constant names in branches the tests
	 * never execute, which is how MoodleType.Panic survived into a shipped 42 folder.
	 */
	private static int checkConstantUsage(String prefix, List<String> valid) throws IOException {
		if (valid.isEmpty()) return 0;
		Set<String> known = new HashSet<String>(valid);
		int bad = 0;
		for (String path : loadFiles) {
			File f = new File(path);
			if (!f.getName().endsWith(".lua")) continue;
			// Only shipped mod source. Specs deliberately reference retired constants.
			if (!f.getCanonicalPath().startsWith(modRoot)) continue;
			BufferedReader r = new BufferedReader(new FileReader(f));
			String line;
			int n = 0;
			try {
				while ((line = r.readLine()) != null) {
					n++;
					// Comments are prose and routinely name a retired constant to explain
					// why it is gone. Only real code is checked.
					int comment = line.indexOf("--");
					if (comment >= 0) line = line.substring(0, comment);

					int at = 0;
					while ((at = line.indexOf(prefix, at)) >= 0) {
						at += prefix.length();
						int end = at;
						while (end < line.length()
							&& (Character.isLetterOrDigit(line.charAt(end)) || line.charAt(end) == '_')) end++;
						String name = line.substring(at, end);
						// Constants are UPPER_SNAKE. A member starting lower case is a
						// method on the class rather than one of its constants, which is
						// how a mod defined trait has to be looked up: CharacterTrait.get
						// takes a ResourceLocation, there being no compiled constant for
						// anything the base game does not ship.
						if (name.length() > 0 && Character.isLowerCase(name.charAt(0))) continue;
						if (name.length() > 0 && !known.contains(name)) {
							bad++;
							System.out.println("  FAIL  unknown " + prefix + name
								+ "  (" + f.getName() + ":" + n + ")");
						}
					}
				}
			} finally {
				r.close();
			}
		}
		if (bad > 0) System.out.println();
		return bad;
	}

	/**
	 * Checks mod item scripts against the shape build 42 actually uses. Every one of
	 * these was a real crash: a legacy "Type" leaves getItemType() null and takes the
	 * debug item spawner down, an un-namespaced BodyLocation never resolves, and
	 * DisplayName is simply ignored so the item shows as its id.
	 */
	private static int checkItemScripts() throws IOException {
		Set<String> vanillaItems = readItemNames(new File(gameDir, "media/scripts"));
		File scripts = new File(modRoot, "42/media/scripts");
		if (!scripts.isDirectory()) return 0;

		java.util.ArrayDeque<File> queue = new java.util.ArrayDeque<File>();
		queue.add(scripts);
		int bad = 0;

		while (!queue.isEmpty()) {
			File dir = queue.poll();
			File[] children = dir.listFiles();
			if (children == null) continue;

			for (File f : children) {
				if (f.isDirectory()) { queue.add(f); continue; }
				if (!f.getName().endsWith(".txt")) continue;

				BufferedReader r = new BufferedReader(new FileReader(f));
				String line;
				int n = 0;
				boolean inItem = false;
				boolean sawItemType = false;
				String itemName = null;
				int itemLine = 0;

				try {
					while ((line = r.readLine()) != null) {
						n++;
						String t = line.trim();

						// A real item definition is "item Name" and nothing else. Recipe
						// ingredients read "item 1 tags[...]," and must not match.
						if (t.matches("item\\s+[A-Za-z_][A-Za-z0-9_.]*")) {
							inItem = true;
							sawItemType = false;
							itemName = t.substring(5).trim();
							itemLine = n;
							continue;
						}
						if (!inItem) continue;

						if (t.startsWith("}")) {
							// A block reopening an item the base game already defines is
							// widening it, not declaring it, and carries no ItemType.
							if (!sawItemType && !vanillaItems.contains(itemName)) {
								bad++;
								System.out.println("  FAIL  item " + itemName + " has no ItemType"
									+ "  (" + f.getName() + ":" + itemLine + ")");
							}
							inItem = false;
							continue;
						}
						if (t.replaceAll("\\s", "").startsWith("ItemType=")) sawItemType = true;

						if (t.replaceAll("\\s", "").startsWith("Type=")) {
							bad++;
							System.out.println("  FAIL  legacy 'Type =' in item " + itemName
								+ ", build 42 wants ItemType  (" + f.getName() + ":" + n + ")");
						}
						if (t.replaceAll("\\s", "").startsWith("DisplayName=")) {
							bad++;
							System.out.println("  FAIL  DisplayName in item " + itemName
								+ ", build 42 takes names from Items_EN  (" + f.getName() + ":" + n + ")");
						}
						java.util.regex.Matcher body = java.util.regex.Pattern
							.compile("^BodyLocation\\s*=\\s*([^,]+),?").matcher(t);
						if (body.find() && !body.group(1).contains(":")) {
							bad++;
							System.out.println("  FAIL  BodyLocation '" + body.group(1).trim()
								+ "' is not namespaced  (" + f.getName() + ":" + n + ")");
						}
					}
				} finally {
					r.close();
				}
			}
		}

		if (bad > 0) System.out.println();
		return bad;
	}

	/**
	 * Checks the sandbox option file against what the game's parser actually accepts,
	 * and against the translation file. A typo in a type or a missing label does not
	 * crash: the option is dropped or renders as its raw key, which is easy to ship
	 * without noticing. Every option is server-controlled balance, so a dropped one
	 * silently falls back to the hardcoded default on every machine.
	 */
	private static int checkSandboxOptions() throws IOException {
		File options = new File(modRoot, "42/media/sandbox-options.txt");
		if (!options.isFile()) return 0;

		// zombie.sandbox.CustomSandboxOptions.parseOption accepts exactly these.
		Set<String> types = new HashSet<String>(
			Arrays.asList("boolean", "double", "enum", "integer", "string"));

		String body = readAll(options);
		// The parser strips /* */ before reading, so the checks here must too.
		body = body.replaceAll("(?s)/\\*.*?\\*/", "");

		int bad = 0;
		if (!body.matches("(?s).*\\bVERSION\\s*=\\s*\\d+.*")) {
			bad++;
			System.out.println("  FAIL  sandbox-options.txt has no VERSION, the parser throws on load");
		}

		Set<String> keys = readTranslationKeys(
			new File(modRoot, "42/media/lua/shared/Translate/EN/Sandbox.json"));

		java.util.regex.Matcher m = java.util.regex.Pattern
			.compile("option\\s+([A-Za-z_][\\w.]*)\\s*\\{(.*?)\\}", java.util.regex.Pattern.DOTALL)
			.matcher(body);

		int found = 0;
		while (m.find()) {
			found++;
			String id = m.group(1);
			String block = m.group(2).replaceAll("\\s", "");

			String type = valueOf(block, "type");
			if (type == null || !types.contains(type)) {
				bad++;
				System.out.println("  FAIL  option " + id + " has type '" + type
					+ "', the parser only accepts " + types);
			}

			String page = valueOf(block, "page");
			if (page != null && !keys.isEmpty() && !keys.contains("Sandbox_" + page)) {
				bad++;
				System.out.println("  FAIL  option " + id + " is on page '" + page
					+ "' but Sandbox.json has no Sandbox_" + page);
			}

			// Hand the declared defaults to the specs, so the stub never has to restate
			// numbers that live in the option file.
			String def = valueOf(block, "default");
			String shortId = id.contains(".") ? id.substring(id.indexOf('.') + 1) : id;
			if (def != null) {
				// An enum reaches lua as its index, not its text: vanilla's own scenarios
				// assign SandboxVars.Alarm = 4. Seeding it as a string here would let a
				// spec pass on a comparison that errors in the game.
				if ("boolean".equals(type)) sandboxDefaults.put(shortId, Boolean.valueOf(def));
				else if ("string".equals(type)) sandboxDefaults.put(shortId, def);
				else sandboxDefaults.put(shortId, Double.valueOf(def));
			}

			String translation = valueOf(block, "translation");
			if (translation == null) {
				bad++;
				System.out.println("  FAIL  option " + id + " declares no translation");
			} else if (!keys.isEmpty() && !keys.contains("Sandbox_" + translation)) {
				bad++;
				System.out.println("  FAIL  option " + id + " has no Sandbox_" + translation
					+ " in Sandbox.json, it would render as the raw key");
			}
		}

		if (found == 0) {
			bad++;
			System.out.println("  FAIL  sandbox-options.txt parsed to zero options");
		}
		if (bad > 0) System.out.println();
		return bad;
	}

	/**
	 * Resolves every getTexture path in shipped mod source against the files that
	 * actually exist, in the mod first and then the game install. A wrong path is not an
	 * error at runtime: getTexture returns null and the image simply never draws, which
	 * is easy to miss on a small icon and impossible to miss on a full screen overlay.
	 *
	 * Mod textures live under common/media or 42/media, and the game resolves a path
	 * like "media/textures/GUI/x.png" against both.
	 */
	private static int checkTexturePaths() throws IOException {
		java.util.regex.Pattern call = java.util.regex.Pattern
			.compile("getTexture\\s*\\(\\s*\"([^\"]+)\"");
		int bad = 0;

		for (String path : loadFiles) {
			File f = new File(path);
			if (!f.getName().endsWith(".lua")) continue;
			if (!f.getCanonicalPath().startsWith(modRoot)) continue;

			BufferedReader r = new BufferedReader(new FileReader(f));
			String line;
			int n = 0;
			try {
				while ((line = r.readLine()) != null) {
					n++;
					int comment = line.indexOf("--");
					if (comment >= 0) line = line.substring(0, comment);

					java.util.regex.Matcher m = call.matcher(line);
					while (m.find()) {
						String texture = m.group(1);
						if (resolveTexture(texture)) continue;
						bad++;
						System.out.println("  FAIL  texture not found: " + texture
							+ "  (" + f.getName() + ":" + n + ")");
					}
				}
			} finally {
				r.close();
			}
		}

		if (bad > 0) System.out.println();
		return bad;
	}

	/**
	 * Resolves every "Module.ItemName" literal in shipped mod source against the items
	 * this build actually defines, in the mod first and then the game.
	 *
	 * A retired item name is silent at runtime. ScriptManager.getItem returns null, a
	 * lookup keyed on the type simply never matches, and the feature does nothing with no
	 * error anywhere. Clothing gets renamed between builds often enough that a table of
	 * item types is worth checking on every run rather than by eye once.
	 */
	private static int checkItemTypes() throws IOException {
		Set<String> known = readItemNames(new File(modRoot, "42/media/scripts"));
		known.addAll(readItemNames(new File(gameDir, "media/scripts")));
		System.out.println("Item types found in this build: " + known.size());

		if (known.isEmpty()) {
			System.out.println("  FAIL  no item scripts found, nothing could be checked");
			return 1;
		}

		java.util.regex.Pattern literal = java.util.regex.Pattern
			.compile("\"([A-Za-z][A-Za-z0-9_]*)\\.([A-Za-z0-9_]+)\"");
		int bad = 0;

		for (String path : loadFiles) {
			File f = new File(path);
			if (!f.getName().endsWith(".lua")) continue;
			if (!f.getCanonicalPath().startsWith(modRoot)) continue;

			BufferedReader r = new BufferedReader(new FileReader(f));
			String line;
			int n = 0;
			try {
				while ((line = r.readLine()) != null) {
					n++;
					int comment = line.indexOf("--");
					if (comment >= 0) line = line.substring(0, comment);

					java.util.regex.Matcher m = literal.matcher(line);
					while (m.find()) {
						String name = m.group(2);
						// Only literals whose bare name is an item somewhere are meant as
						// item types. Anything else is a texture path or a lua field and
						// is none of this check's business.
						if (known.contains(name)) continue;
						if (!looksLikeItemType(m.group(1))) continue;

						bad++;
						System.out.println("  FAIL  no such item in this build: "
							+ m.group(1) + "." + name + "  (" + f.getName() + ":" + n + ")");
					}
				}
			} finally {
				r.close();
			}
		}

		if (bad > 0) System.out.println();
		return bad;
	}

	/**
	 * Modules that name items. Restricted so a stray "Events.OnTick" style literal is not
	 * reported as a missing item, while a typo inside a real module still is.
	 */
	private static boolean looksLikeItemType(String module) {
		return module.equals("Base") || module.equals("QoLC");
	}

	/** Every "item Name" declared under a scripts directory, bare names, no module. */
	private static Set<String> readItemNames(File scripts) throws IOException {
		Set<String> names = new HashSet<String>();
		if (!scripts.isDirectory()) return names;

		java.util.regex.Pattern decl = java.util.regex.Pattern
			.compile("^\\s*item\\s+([A-Za-z0-9_.]+)\\s*$");

		java.util.ArrayDeque<File> queue = new java.util.ArrayDeque<File>();
		queue.add(scripts);

		while (!queue.isEmpty()) {
			File dir = queue.poll();
			File[] children = dir.listFiles();
			if (children == null) continue;

			for (File f : children) {
				if (f.isDirectory()) { queue.add(f); continue; }
				if (!f.getName().endsWith(".txt")) continue;

				BufferedReader r = new BufferedReader(new FileReader(f));
				String line;
				try {
					while ((line = r.readLine()) != null) {
						java.util.regex.Matcher m = decl.matcher(line);
						if (m.matches()) names.add(m.group(1));
					}
				} finally {
					r.close();
				}
			}
		}
		return names;
	}

	/**
	 * Diffs every tile definition the mod ships against the installed build's own.
	 *
	 * A tileset can only be replaced whole, so fixing one property on eight flamingo tiles
	 * means shipping all fifty tiles of vegetation_ornamental_01. Everything except that
	 * one property is a copy, and a copy silently wins over whatever the game ships next.
	 * That is the entire risk of the approach, and this is what converts it from a silent
	 * revert into a failed build: any difference other than the intended one is reported,
	 * and tools/generate_flamingo_tiles.py regenerates the file.
	 */
	private static int checkTileDefs() throws IOException {
		File dir = new File(modRoot, "common/media");
		File[] files = dir.listFiles();
		if (files == null) return 0;

		int bad = 0;
		for (File f : files) {
			if (!f.getName().endsWith(".tiles")) continue;
			bad += checkTileDefFile(f);
		}
		return bad;
	}

	/** Intentional differences: the property, and the tiles it may be missing from. */
	private static final String DROPPED_PROPERTY = "attachedFloor";
	private static final String DROPPED_FROM = "Flamingo";

	private static int checkTileDefFile(File file) throws IOException {
		Map<String, Map<String, String>> ours;
		try {
			ours = readTileDefBinary(file);
		} catch (IOException e) {
			System.out.println("  FAIL  " + file.getName() + " could not be read: " + e.getMessage());
			System.out.println("        regenerate with tools/generate_flamingo_tiles.py");
			System.out.println();
			return 1;
		}

		int bad = 0;
		int checked = 0;
		int intended = 0;

		Map<String, Map<String, String>> theirs = readTileDefDump();

		for (Map.Entry<String, Map<String, String>> e : ours.entrySet()) {
			Map<String, String> mine = e.getValue();
			Map<String, String> vanilla = theirs.get(e.getKey());
			checked++;

			if (vanilla == null) {
				bad++;
				System.out.println("  FAIL  " + file.getName() + " defines " + e.getKey()
					+ ", which this build does not have");
				continue;
			}

			// Every property we carry must match, and every one vanilla carries must be
			// present, apart from the single one this is allowed to remove.
			Set<String> keys = new HashSet<String>(mine.keySet());
			keys.addAll(vanilla.keySet());

			for (String key : keys) {
				String a = mine.get(key);
				String b = vanilla.get(key);
				if (a != null && a.equals(b)) continue;

				boolean allowed = a == null && key.equals(DROPPED_PROPERTY)
					&& DROPPED_FROM.equals(vanilla.get("CustomName"));
				if (allowed) { intended++; continue; }

				bad++;
				System.out.println("  FAIL  " + file.getName() + " " + e.getKey()
					+ " " + key + ": ships " + (a == null ? "nothing" : "\"" + a + "\"")
					+ ", this build has " + (b == null ? "nothing" : "\"" + b + "\""));
			}
		}

		// Drift is only half of it. A file that matched vanilla exactly would pass every
		// check above while fixing nothing, and still freeze the tileset, so the change
		// this exists to make has to be present on every tile it applies to.
		int expected = 0;
		for (Map.Entry<String, Map<String, String>> e : theirs.entrySet()) {
			if (!ours.containsKey(e.getKey())) continue;
			if (DROPPED_FROM.equals(e.getValue().get("CustomName"))
				&& e.getValue().containsKey(DROPPED_PROPERTY)) expected++;
		}

		if (bad == 0 && intended != expected) {
			bad++;
			System.out.println("  FAIL  " + file.getName() + " drops " + DROPPED_PROPERTY
				+ " from " + intended + " " + DROPPED_FROM + " tiles, expected " + expected);
		}

		if (bad == 0) {
			System.out.println("Tile definitions checked: " + checked + " tiles, "
				+ intended + " intended change(s)");
		} else {
			System.out.println("        regenerate with tools/generate_flamingo_tiles.py");
			System.out.println();
		}
		return bad;
	}

	/** "<tileset>_<index>" -> properties, from a .tiles binary. */
	private static Map<String, Map<String, String>> readTileDefBinary(File file) throws IOException {
		DataInputStream in = new DataInputStream(new BufferedInputStream(new FileInputStream(file)));
		Map<String, Map<String, String>> tiles = new LinkedHashMap<String, Map<String, String>>();
		try {
			byte[] magic = new byte[4];
			in.readFully(magic);
			if (!"tdef".equals(new String(magic, "UTF-8"))) {
				System.out.println("  FAIL  " + file.getName() + " is not a tile definition file");
				return tiles;
			}

			readLittleInt(in);                       // version
			int sets = readLittleInt(in);

			for (int s = 0; s < sets; s++) {
				String name = readLine(in);
				readLine(in);                        // png
				readLittleInt(in);                   // width
				readLittleInt(in);                   // height
				readLittleInt(in);                   // tileset number within the file
				int count = readLittleInt(in);

				// Bounded on purpose. A count read out of a corrupt file is arbitrary, and
				// without a ceiling the reader spins on empty strings instead of failing.
				if (count < 0 || count > 4096) {
					throw new IOException("implausible tile count " + count + " in " + name);
				}

				for (int t = 0; t < count; t++) {
					int props = readLittleInt(in);
					if (props == 0) continue;
					if (props < 0 || props > 256) {
						throw new IOException("implausible property count " + props
							+ " on " + name + "_" + t);
					}

					Map<String, String> map = new LinkedHashMap<String, String>();
					for (int p = 0; p < props; p++) {
						String key = readLine(in);
						map.put(key, readLine(in));
					}
					tiles.put(name + "_" + t, map);
				}
			}
		} finally {
			in.close();
		}
		return tiles;
	}

	/** The same shape, from the readable dump the game ships beside its own binary. */
	private static Map<String, Map<String, String>> readTileDefDump() throws IOException {
		Map<String, Map<String, String>> tiles = new LinkedHashMap<String, Map<String, String>>();
		File dump = new File(gameDir, "media/newtiledefinitions.tiles.txt");
		if (!dump.isFile()) return tiles;

		BufferedReader r = new BufferedReader(new InputStreamReader(new FileInputStream(dump), "UTF-8"));
		try {
			String line;
			String set = null;
			int width = 8;
			Map<String, String> current = null;

			while ((line = r.readLine()) != null) {
				String t = line.trim();

				// A tile ends at its closing brace. Without this the tileset header that
				// follows, size and id, is read as more properties of the last tile.
				if (t.equals("}")) {
					current = null;
				} else if (t.startsWith("file = ")) {
					set = t.substring(7).trim();
				} else if (t.startsWith("size = ")) {
					width = Integer.parseInt(t.substring(7).split(",")[0].trim());
				} else if (t.equals("tile")) {
					current = new LinkedHashMap<String, String>();
				} else if (t.startsWith("xy = ") && current != null && set != null) {
					String[] xy = t.substring(5).split(",");
					int index = Integer.parseInt(xy[1].trim()) * width + Integer.parseInt(xy[0].trim());
					tiles.put(set + "_" + index, current);
				} else if (current != null && t.contains(" = ")) {
					int at = t.indexOf(" = ");
					String key = t.substring(0, at);
					if (!key.equals("xy")) current.put(key, t.substring(at + 3).trim());
				} else if (current != null && t.endsWith("=") && t.length() > 1) {
					current.put(t.substring(0, t.length() - 1).trim(), "");
				}
			}
		} finally {
			r.close();
		}
		return tiles;
	}

	private static int readLittleInt(DataInputStream in) throws IOException {
		return in.readUnsignedByte() | (in.readUnsignedByte() << 8)
			| (in.readUnsignedByte() << 16) | (in.readUnsignedByte() << 24);
	}

	/** Strings in this format are newline terminated rather than length prefixed. */
	private static String readLine(DataInputStream in) throws IOException {
		StringBuilder sb = new StringBuilder();
		int c;
		while ((c = in.read()) != -1 && c != '\n') sb.append((char) c);
		// Running off the end quietly is what turns a malformed file into a hang rather
		// than a failure, because every later read then succeeds with nothing in it.
		if (c == -1) throw new IOException("unexpected end of tile definition file");
		return sb.toString();
	}

	/** True when a "media/..." path exists in the mod's own trees or in the game. */
	/**
	 * Texture paths assembled with string.format. The placeholders make the full name
	 * unknowable from source, so what is checked is the directory the path starts with:
	 * it has to exist and hold something. That is enough to catch a folder deleted or
	 * renamed out from under the code, which a literal by literal check cannot see.
	 */
	private static int checkTextureFolders() throws IOException {
		java.util.regex.Pattern call = java.util.regex.Pattern
			.compile("string\\.format\\s*\\(\\s*\"(media/[^\"]*?)%");
		int bad = 0;

		for (String path : loadFiles) {
			File f = new File(path);
			if (!f.getName().endsWith(".lua")) continue;
			if (!f.getCanonicalPath().startsWith(modRoot)) continue;

			BufferedReader r = new BufferedReader(new FileReader(f));
			String line;
			int n = 0;
			try {
				while ((line = r.readLine()) != null) {
					n++;
					int comment = line.indexOf("--");
					if (comment >= 0) line = line.substring(0, comment);

					java.util.regex.Matcher m = call.matcher(line);
					while (m.find()) {
						String prefix = m.group(1);
						int slash = prefix.lastIndexOf('/');
						if (slash < 0) continue;

						String dir = prefix.substring(0, slash);
						if (resolveTextureFolder(dir)) continue;
						bad++;
						System.out.println("  FAIL  texture folder empty or missing: " + dir
							+ "  (" + f.getName() + ":" + n + ")");
					}
				}
			} finally {
				r.close();
			}
		}

		if (bad > 0) System.out.println();
		return bad;
	}

	private static boolean resolveTextureFolder(String folder) {
		String relative = folder.startsWith("media/") ? folder.substring("media/".length()) : folder;

		File[] roots = {
			new File(modRoot, "common/media"),
			new File(modRoot, "42/media"),
			new File(gameDir, "media")
		};
		for (File root : roots) {
			File dir = new File(root, relative);
			String[] held = dir.list();
			if (dir.isDirectory() && held != null && held.length > 0) return true;
		}
		return false;
	}

	private static boolean resolveTexture(String texture) {
		String relative = texture.startsWith("media/") ? texture.substring("media/".length()) : texture;

		File[] roots = {
			new File(modRoot, "common/media"),
			new File(modRoot, "42/media"),
			new File(gameDir, "media")
		};
		for (File root : roots) {
			if (new File(root, relative).isFile()) return true;
		}
		return false;
	}

	private static String valueOf(String block, String key) {
		java.util.regex.Matcher m = java.util.regex.Pattern
			.compile("(?:^|,)" + key + "=([^,}]+)").matcher(block);
		return m.find() ? m.group(1) : null;
	}

	/**
	 * Every craftRecipe this mod ships needs a display name in Recipes.json, keyed by the
	 * recipe's own name. Without one the crafting menu prints the raw name, which is how
	 * "QolcMakeLockpickFromHairpin" reached a player's screen: nothing errors, nothing
	 * warns, the recipe simply reads like a variable.
	 */
	private static int checkRecipeNames() throws IOException {
		File scripts = new File(modRoot, "42/media/scripts");
		if (!scripts.isDirectory()) return 0;

		Set<String> keys = readTranslationKeys(
			new File(modRoot, "42/media/lua/shared/Translate/EN/Recipes.json"));
		if (keys.isEmpty()) return 0;

		// A recipe block that names one the base game already ships is an override, adding
		// an OnCreate hook or the like, and the name it displays under is vanilla's. Only
		// a recipe this mod introduces needs a name of its own.
		keys.addAll(readTranslationKeys(new File(gameDir,
			"media/lua/shared/Translate/EN/Recipes.json")));

		java.util.ArrayDeque<File> queue = new java.util.ArrayDeque<File>();
		queue.add(scripts);

		int bad = 0;
		java.util.regex.Pattern p = java.util.regex.Pattern
			.compile("(?m)^\\s*craftRecipe\\s+(\\S+)\\s*$");

		while (!queue.isEmpty()) {
			File dir = queue.poll();
			File[] children = dir.listFiles();
			if (children == null) continue;

			for (File f : children) {
				if (f.isDirectory()) { queue.add(f); continue; }
				if (!f.getName().endsWith(".txt")) continue;

				String body = readAll(f).replaceAll("(?s)/\\*.*?\\*/", "");
				java.util.regex.Matcher m = p.matcher(body);
				while (m.find()) {
					String name = m.group(1);
					if (!keys.contains(name)) {
						bad++;
						System.out.println("  FAIL  craftRecipe " + name
							+ " has no name in Recipes.json, the menu shows the raw name"
							+ "  (" + f.getName() + ")");
					}
				}
			}
		}

		if (bad > 0) System.out.println();
		return bad;
	}

	private static Set<String> readTranslationKeys(File f) throws IOException {
		Set<String> keys = new HashSet<String>();
		if (!f.isFile()) return keys;
		java.util.regex.Matcher m = java.util.regex.Pattern
			.compile("\"(.+?)\"\\s*:").matcher(readAll(f));
		while (m.find()) keys.add(m.group(1));
		return keys;
	}

	/** The name of every table in vanilla's ProceduralDistributions, in file order. */
	private static List<String> readProceduralNames() throws IOException {
		List<String> found = new ArrayList<String>();
		File file = new File(gameDir, "media/lua/server/Items/ProceduralDistributions.lua");
		if (!file.isFile()) return found;

		java.util.regex.Matcher m = java.util.regex.Pattern
			.compile("^\\t(\\w+)\\s*=\\s*\\{", java.util.regex.Pattern.MULTILINE)
			.matcher(readAll(file));
		while (m.find()) found.add(m.group(1));

		return found;
	}

	/**
	 * Tags this mod adds to an item the base game already defines. Reopening a vanilla
	 * item to widen its tags only works while those tag names still exist, and a tag the
	 * build does not know is accepted in silence: it becomes a tag nothing else carries,
	 * so the item joins no recipe and nothing reports it. Every tag named here has to be
	 * one this build actually uses somewhere.
	 */
	private static int checkTagPatches() throws IOException {
		Set<String> vanillaTags = readTagNames(new File(gameDir, "media/scripts"));
		if (vanillaTags.isEmpty()) {
			System.out.println("  FAIL  no vanilla tags found, nothing could be checked");
			return 1;
		}
		System.out.println("Item tags found in this build: " + vanillaTags.size());

		Set<String> ours = readTagNames(new File(modRoot, "42/media/scripts"));
		Set<String> weUse = readTagUses(new File(modRoot, "42/media/scripts"));

		int bad = 0;
		for (String tag : ours) {
			if (vanillaTags.contains(tag)) continue;
			if (weUse.contains(tag)) continue;
			bad++;
			System.out.println("  FAIL  tag is neither known to this build nor used by us: " + tag);
		}

		if (bad > 0) System.out.println();
		return bad;
	}

	/** Every tag this mod's own recipes ask for, from tags[a;b] in an input line. */
	private static Set<String> readTagUses(File scripts) throws IOException {
		Set<String> found = new LinkedHashSet<String>();
		if (!scripts.isDirectory()) return found;

		java.util.regex.Pattern call = java.util.regex.Pattern.compile("tags\\[([^\\]]+)\\]");

		java.util.ArrayDeque<File> queue = new java.util.ArrayDeque<File>();
		queue.add(scripts);
		while (!queue.isEmpty()) {
			File dir = queue.poll();
			File[] files = dir.listFiles();
			if (files == null) continue;
			for (File f : files) {
				if (f.isDirectory()) { queue.add(f); continue; }
				if (!f.getName().endsWith(".txt")) continue;

				java.util.regex.Matcher m = call.matcher(readAll(f));
				while (m.find()) {
					for (String tag : m.group(1).split(";")) {
						tag = tag.trim();
						if (tag.length() > 0) found.add(tag);
					}
				}
			}
		}

		return found;
	}

	/** Every name appearing in a Tags = a;b;c line under the given scripts directory. */
	private static Set<String> readTagNames(File scripts) throws IOException {
		Set<String> found = new LinkedHashSet<String>();
		if (!scripts.isDirectory()) return found;

		java.util.regex.Pattern line = java.util.regex.Pattern
			.compile("^\\s*Tags\\s*=\\s*([^,]+),?\\s*$", java.util.regex.Pattern.MULTILINE);

		java.util.ArrayDeque<File> queue = new java.util.ArrayDeque<File>();
		queue.add(scripts);
		while (!queue.isEmpty()) {
			File dir = queue.poll();
			File[] files = dir.listFiles();
			if (files == null) continue;
			for (File f : files) {
				if (f.isDirectory()) { queue.add(f); continue; }
				if (!f.getName().endsWith(".txt")) continue;

				java.util.regex.Matcher m = line.matcher(readAll(f));
				while (m.find()) {
					for (String tag : m.group(1).split(";")) {
						tag = tag.trim();
						if (tag.length() > 0) found.add(tag);
					}
				}
			}
		}

		return found;
	}

	/**
	 * Lua can only call methods on Java classes LuaManager exposes. A method that hands
	 * back an unexposed class returns something Lua cannot touch at all: every call on it
	 * throws "attempted index: X of non-table", at runtime, in front of a player.
	 *
	 * That shipped once. BaseVehicle.getParts() returns a VehicleParts, which is not
	 * exposed, and the harness happily answered size() and get() on a stub of it because
	 * the stub was written to match the same wrong belief as the code. Two players hit the
	 * crash before anyone did.
	 *
	 * So this reads the exposed list out of the Exposer's own constant pool, reflects
	 * every method those classes offer, and flags any local this mod assigns from a call
	 * returning an unexposed type and then calls a method on.
	 */
	private static int checkExposedReturns() throws IOException {
		Set<String> exposed = readExposedClasses();
		if (exposed.isEmpty()) {
			System.out.println("  FAIL  could not read LuaManager's exposed class list");
			return 1;
		}
		System.out.println("Classes exposed to lua in this build: " + exposed.size());

		// Method name to the zombie types it can return, across every exposed class.
		Map<String, Set<String>> returns = new LinkedHashMap<String, Set<String>>();
		for (String name : exposed) {
			Class<?> owner;
			try {
				owner = Class.forName(name, false, TestRunner.class.getClassLoader());
			} catch (Throwable t) {
				continue;
			}
			Method[] methods;
			try {
				methods = owner.getMethods();
			} catch (Throwable t) {
				continue;
			}
			for (Method m : methods) {
				Class<?> ret = m.getReturnType();
				if (ret.isPrimitive() || !ret.getName().startsWith("zombie.")) continue;

				Set<String> types = returns.get(m.getName());
				if (types == null) {
					types = new LinkedHashSet<String>();
					returns.put(m.getName(), types);
				}
				types.add(ret.getName());
			}
		}

		java.util.regex.Pattern assign = java.util.regex.Pattern
			.compile("local\\s+(\\w+)\\s*=\\s*\\w+[:.](\\w+)\\s*\\(");
		int bad = 0;

		for (String path : loadFiles) {
			File f = new File(path);
			if (!f.getName().endsWith(".lua")) continue;
			if (!f.getCanonicalPath().startsWith(modRoot)) continue;

			String[] lines = readAll(f).split("\\n");
			for (int n = 0; n < lines.length; n++) {
				String line = lines[n];
				int comment = line.indexOf("--");
				if (comment >= 0) line = line.substring(0, comment);

				java.util.regex.Matcher m = assign.matcher(line);
				while (m.find()) {
					String local = m.group(1);
					Set<String> types = returns.get(m.group(2));
					if (types == null || types.isEmpty()) continue;

					// Only when every type it can return is one lua cannot touch.
					boolean anyExposed = false;
					for (String t : types) if (exposed.contains(t)) anyExposed = true;
					if (anyExposed) continue;

					if (!usesLocal(lines, n + 1, local)) continue;

					bad++;
					System.out.println("  FAIL  " + m.group(2) + "() returns "
						+ types.iterator().next() + ", which lua cannot call into"
						+ "  (" + f.getName() + ":" + (n + 1) + ")");
				}
			}
		}

		if (bad > 0) System.out.println();
		return bad;
	}

	/** Whether a local is called as an object after the line it was assigned on. */
	private static boolean usesLocal(String[] lines, int from, String local) {
		java.util.regex.Pattern use = java.util.regex.Pattern
			.compile("\\b" + java.util.regex.Pattern.quote(local) + "\\s*[:]");

		for (int i = from; i < lines.length; i++) {
			if (use.matcher(lines[i]).find()) return true;
		}
		return false;
	}

	/** Class names appearing in LuaManager$Exposer, which is what lua may call into. */
	private static Set<String> readExposedClasses() throws IOException {
		Set<String> found = new LinkedHashSet<String>();
		File jar = new File(gameDir, "projectzomboid.jar");
		if (!jar.isFile()) return found;

		java.util.zip.ZipFile zip = new java.util.zip.ZipFile(jar);
		try {
			java.util.zip.ZipEntry entry = zip.getEntry("zombie/Lua/LuaManager$Exposer.class");
			if (entry == null) return found;

			ByteArrayOutputStream out = new ByteArrayOutputStream();
			InputStream in = zip.getInputStream(entry);
			byte[] buffer = new byte[8192];
			int read;
			while ((read = in.read(buffer)) > 0) out.write(buffer, 0, read);
			in.close();

			java.util.regex.Matcher m = java.util.regex.Pattern
				.compile("zombie/[A-Za-z0-9_/$]+")
				.matcher(new String(out.toByteArray(), "ISO-8859-1"));
			while (m.find()) found.add(m.group().replace('/', '.'));
		} finally {
			zip.close();
		}

		return found;
	}

	private static String readAll(File f) throws IOException {
		StringBuilder sb = new StringBuilder();
		BufferedReader r = new BufferedReader(new InputStreamReader(new FileInputStream(f), "UTF-8"));
		try {
			String line;
			while ((line = r.readLine()) != null) sb.append(line).append('\n');
		} finally {
			r.close();
		}
		return sb.toString();
	}

	private static String rootCause(Throwable t) {
		Throwable c = t;
		while (c.getCause() != null) c = c.getCause();
		return c.toString();
	}

	private static class Result {
		String name;
		boolean ok;
		String error = "";
	}
}
