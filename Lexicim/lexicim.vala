using GLib;
using Gtk;
using Gee;

/**
 * Gtk+ input method implementation that provides completion suggestions from a dictionary
 */
public class Lexicim.Lexicim: Gtk.IMContext {
	public const string linux_default_dictionary_path = "/usr/share/dict";
	public const string im_name = "Lexicim";
	
	/// List of valid completions
	static string[] words;
	
	/// Map of char => index into words of first entry beginning with char
	static Map<unichar,int> indices;
	
	/// The index into words of the last suggested completion
	int lastMatchedIndex;
	
	/// Whether completion is currently enabled
	bool enabled;
	
	public Lexicim () {
		lastMatchedIndex = -1;
	}// constructor
	
	/**
	 * Gets the current completion suggestion
	 * @see Gtk.IMContext.get_preedit_string
	 */
	public override void get_preedit_string (out string str, out Pango.AttrList attrs, out int pos) {
		str = "";
		pos = 0;
		attrs = new Pango.AttrList ();
		
		// Don't try to complete if there's no dictionary or completion is disabled
		if (!enabled || null == words){ return; }
		
		// Get the completion token
		unowned string? surrounding = null;
		int surrounding_position = 0;
		bool must_free_surrounding = get_surrounding (out surrounding, out surrounding_position);
		string token = get_token (surrounding, surrounding_position);
		
		if (2 < token.length) {
			// Lookup the token, and display the suggested completion in italics
			str = lookup (token).offset (token.length);
			pos = 0;
			attrs.insert (Pango.attr_style_new (Pango.Style.ITALIC));
		}// only do lookups on 3+-letter words
		
		stdout.printf ("Using preedit string '%s' for surrounding '%s'\n", str, surrounding);
		
		// Goofy api
		if (must_free_surrounding){ GLib.free ((void*)surrounding); }
	}// get_preedit_string
	
	/**
	 * Intercept keypresses to trigger completion appropriately
	 * @see Gtk.IMContext.filter_keypress
	 */
	public override bool filter_keypress (Gdk.EventKey event) {
		bool handled = false;
		
		if (Gdk.EventType.KEY_PRESS == event.type) {
			// key press
			stdout.printf("Got keypress %u\n", event.keyval);
			string commit_string = event.str;
			
			switch (event.keyval) {
			case Gdk.Key_Return:
			case Gdk.Key_KP_Enter: 
			case Gdk.Key_ISO_Enter:
				// Commit completion on enter press
				string preedit;
				Pango.AttrList attrs;
				int pos;
				--lastMatchedIndex;
				get_preedit_string(out preedit, out attrs, out pos);
				if (0 < preedit.length) {
					commit_string = "%s ".printf (preedit);
					handled = true;
				} else {
					commit_string = "";
				}// Don't intercept keystrokes on empty completions
				
				commit (commit_string);
				enabled = false;
				reset ();
				preedit_changed ();
				break;
			case Gdk.Key_BackSpace:
			case Gdk.Key_Delete:
			case Gdk.Key_KP_Delete:
				// Clear completion on backspace/delete
				enabled = false;
				reset ();
				preedit_changed ();
				break;
			case Gdk.Key_Left:
			case Gdk.Key_leftarrow:
			case Gdk.Key_KP_Left:
				// Cycle backward through completions
				lastMatchedIndex-=2;
				preedit_changed ();
				handled = enabled;
				break;
			case Gdk.Key_Right:
			case Gdk.Key_rightarrow:
			case Gdk.Key_KP_Right:
				// Cycle forward through completions
				preedit_changed ();
				handled = enabled;
				break;
			case Gdk.Key_KP_Space:
			case Gdk.Key_space:
				// Special-case space input - this was necessary for xchat
				commit (commit_string);
				reset ();
				preedit_changed ();
				handled = true;
				break;
			default:
				// Commit and pass through printable keypresses
				enabled = event.str[0].isprint ();
				if (enabled) {
					commit (commit_string);
				}
				reset ();
				preedit_changed ();
				break;
			}
		} else if (Gdk.EventType.KEY_RELEASE == event.type && 
		           Gdk.Key_Tab == event.keyval) {
			// Special-case tab release - this was necessary for gedit
			enabled = false;
			reset ();
			preedit_changed ();
		} else {
			stdout.printf("Got event type %d\n", (int)event.type);
		}// switch on event type
		
		return handled;
	}// filter_keypress
	
	/**
	 * Reset completion state
	 * @see Gtk.IMContext.reset
	 */
	public override void reset () {
		lastMatchedIndex = -1;
	}// reset
	
	/**
	 * Gets the token at a given position in a string
	 * @param surrounding The string from which to split the token
	 * @param position A position in surrounding containing a token
	 * @return The found token, or empty string
	 */
	static string get_token (string surrounding, int position) {
		string token = "";
		string tmp = "";
		stdout.printf ("Searching for token in '%s:%d'\n", surrounding, position);
		
		if (0 < position && surrounding[position-1].isalpha ()) {
			// Split at position, replace nonword with space, extract last space-delimited chunk
			token = surrounding.substring (0, position);
			token = token.replace ("[^\\w]", " ");
			tmp = token.rchr (token.length-1, ' ');
			if (null != tmp) { token = tmp.strip(); }
		} else {
			stdout.printf("Invalid char: '%c' at %d\n", (char)surrounding[position], position);
		}// only find alphabetic tokens
		
		return token;
	}// get_token
	
	/**
	 * Loads a dictionary for completion
	 * @param language The name of the dictionary to use
	 * @param path The path in which the dictionary is found (defaults to linux_default_dictionary_path)
	 */
	public static void load_dictionary(string language, string path = linux_default_dictionary_path) {
		indices = new HashMap<unichar, int> ();
		string fullpath = Path.build_filename (linux_default_dictionary_path, language);
		if (FileUtils.test (fullpath, FileTest.EXISTS)) {
			string contents = "";
			size_t length = 0;
			
			try {
				FileUtils.get_contents (fullpath, out contents, out length);
			} catch (FileError fe) {
				stderr.printf("%s: Error opening %s: %s\n", im_name, fullpath, fe.message);
			}
			
			words = contents.split ("\n");
			
			// Cache letter positions
			int i = 0;
			foreach (unowned string word in words) {
				if (0 < word.length && !indices.contains (word[0])) {
					indices[word[0]] = i;
				}
				++i;
			}
			stdout.printf("%s: Dictionary %s loaded.\n", im_name, language);
		}// if dictionary exists
	}// load_dictionary
	
	/**
	 * Lookup a token in the dictionary
	 * @param token The token to lookup
	 * @return The first match after words[lastMatchedIndex] 
	 * that matches at least token.length characters 
	 * and at least as many characters matched in words[lastMatchedIndex]
	 */
	public string lookup (string token) {
		int matchedCharacters = 0,
		    tmp = 0,
		    firstIndex = 0;
		
		stdout.printf("Looking up %s\n", token);
		
		if (0 < lastMatchedIndex) {
			// We've previously matched - cycle through equally good matches
			firstIndex = lastMatchedIndex+1;
			matchedCharacters = match_characters (token, words[lastMatchedIndex]);
			if (matchedCharacters > match_characters (token, words[firstIndex])) {
				firstIndex = indices[token[0]];
			}// we've hit the end of the good matches; start over
			
			for (int i=firstIndex; i<words.length; ++i) {
				tmp = match_characters (token, words[i]); 
				if (matchedCharacters < tmp) {
					// Found better match
					matchedCharacters = tmp;
					stdout.printf("Matched %d characters of %s\n", tmp, words[i]);
					firstIndex = i;
				} else if (matchedCharacters > tmp) {
					// Passed last good match
					if (token.length == matchedCharacters) {
						// Return first of equally good matches
						stdout.printf("Best match for %s is %s\n", token, words[firstIndex]);
						lastMatchedIndex = firstIndex;
						return words[firstIndex];
					} else {
						break;
					}// Don't return completions that don't match the full token
				}// switch on match quality
			}// for each word
		} else if (indices.contains (token[0])) {
			// No previous match - search this section from the beginning
			matchedCharacters = 1;
		    firstIndex = indices[token[0]];
		    
			for (int i=indices[token[0]]; i<words.length; ++i) {
				tmp = match_characters (token, words[i]);
				if (tmp > matchedCharacters && token.length < words[i].length) {
					// Found better match
					firstIndex = i;
					matchedCharacters = tmp;
				} else if (tmp < matchedCharacters) {
					// Passed last good match
					if (token.length == matchedCharacters) {
						lastMatchedIndex = firstIndex;
						return words[firstIndex];
					} else {
						break;
					}// Don't return completions that don't match the full token
				}// switch on match quality
			}// for each word
		}// switch on existence of previous match
		
		return token;
	}// lookup
	
	/**
	 * Count the leading, matching characters in two strings
	 * @param a A string
	 * @param z A string
	 * @return The number of leading characters that were the same in both strings
	 */
	static int match_characters (string a, string z) {
		int i=0;
		
		for (i=0; i<a.length && i<z.length; ++i) {
			if (a[i] != z[i]){ break; }
		}// loop characters until end of string or one differs
		
		return i;
	}// match_characters
}// Lexicim
