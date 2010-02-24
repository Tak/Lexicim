using GLib;
using Gtk;
using Gee;

public class Lexicim.Lexicim: Gtk.IMContext {
	public const string linux_default_dictionary_path = "/usr/share/dict";
	public const string im_name = "Lexicim";
	static string[] words;
	static Map<unichar,int> indices;
	
	int lastMatchedIndex;
	bool enabled;
	
	public Lexicim () {
		lastMatchedIndex = -1;
	}// constructor
	
	public override void get_preedit_string (out string str, out Pango.AttrList attrs, out int pos) {
		str = "";
		pos = 0;
		attrs = new Pango.AttrList ();
		if (!enabled || null == words){ return; }
		
		unowned string? surrounding = null;
		int surrounding_position = 0;
		bool must_free_surrounding = get_surrounding (out surrounding, out surrounding_position);
		string token = get_token (surrounding, surrounding_position);
		
		if (2 < token.length) {
			str = lookup (token).offset (token.length);
			pos = 0;
		}// only do lookups on 3+-letter words
		
		stdout.printf ("Using preedit string '%s' for surrounding '%s'\n", str, surrounding);
		
		if (must_free_surrounding){ GLib.free ((void*)surrounding); }
	}// get_preedit_string
	
	public override bool filter_keypress (Gdk.EventKey event) {
		bool handled = false;
		
		if (Gdk.EventType.KEY_PRESS == event.type) {
			stdout.printf("Got keypress %u\n", event.keyval);
			string commit_string = event.str;
			
			switch (event.keyval) {
			case Gdk.Key_Return:
			case Gdk.Key_KP_Enter: 
			case Gdk.Key_ISO_Enter:
				string preedit;
				Pango.AttrList attrs;
				int pos;
				get_preedit_string(out preedit, out attrs, out pos);
				if (0 < preedit.length) {
					commit_string = "%s ".printf (preedit);
					handled = true;
				} else {
					commit_string = "";
				}
				reset ();
				break;
			case Gdk.Key_BackSpace:
			case Gdk.Key_Delete:
			case Gdk.Key_KP_Delete:
				enabled = false;
				reset ();
				preedit_changed ();
				break;
			default:
				if (event.str[0].isalpha()) {
					enabled = true;
					stdout.printf("Committing %s\n", commit_string);
					commit (commit_string);
					reset ();
					preedit_changed ();
				} else {
					enabled = false;
					reset ();
					preedit_changed ();
				}
				break;
			}
		} else if (Gdk.EventType.KEY_RELEASE == event.type && 
		           Gdk.Key_Tab == event.keyval) {
			enabled = false;
			reset ();
			preedit_changed ();
		} else {
			stdout.printf("Got event type %d\n", (int)event.type);
		}
		
		return handled;
	}// filter_keypress
	
	public override void reset () {
		lastMatchedIndex = -1;
	}// reset
	
	static string get_token (string surrounding, int position) {
		string token = "";
		string tmp = "";
		stdout.printf ("Searching for token in '%s:%d'\n", surrounding, position);
		
		if (0 < position && surrounding[position-1].isalpha ()) {
			token = surrounding.substring (0, position);
			token = token.replace ("[^\\w]", " ");
			tmp = token.rchr (token.length-1, ' ');
			if (null != tmp) { token = tmp.strip(); }
		} else {
			stdout.printf("Invalid char: '%c' at %d\n", (char)surrounding[position], position);
		}
		
		return token;
	}// get_token
	
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
		}
	}// load_dictionary
	
	public string lookup (string token) {
		int matchedCharacters = 0,
		    tmp = 0,
		    firstIndex = 0;
		
		stdout.printf("Looking up %s\n", token);
		
		if (0 < lastMatchedIndex) {
			// We've previously matched - cycle through equally good matches
			firstIndex = lastMatchedIndex;
			matchedCharacters = match_characters (token, words[lastMatchedIndex]);
			for (int i=lastMatchedIndex+1; i<words.length; ++i) {
				tmp = match_characters (token, words[i]); 
				if (matchedCharacters < tmp) {
					stdout.printf("Matched %d characters of %s\n", tmp, words[i]);
					firstIndex = i;
				} else if (matchedCharacters > tmp) {
					stdout.printf("Best match for %s is %s\n", token, words[lastMatchedIndex]);
					return words[firstIndex];
				}
			}
		} else if (indices.contains (token[0])) {
			matchedCharacters = 1;
		    firstIndex = indices[token[0]];
		    
			for (int i=indices[token[0]]; i<words.length; ++i) {
				tmp = match_characters (token, words[i]);
				if (tmp > matchedCharacters && token.length < words[i].length) {
					firstIndex = i;
					matchedCharacters = tmp;
				} else if (tmp < matchedCharacters) {
					lastMatchedIndex = firstIndex;
					return words[firstIndex];
				}
			}
		} // No previous match - search this section from the beginning
		
		return token;
	}// lookup
	
	static int match_characters (string a, string z) {
		int i=0;
		
		for (i=0; i<a.length && i<z.length; ++i) {
			if (a[i] != z[i]){ break; }
		}
		
		return i;
	}// match_characters
}// Lexicim
