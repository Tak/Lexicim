using GLib;
using Gtk;

public class Lexicim.Lexicim: Gtk.IMContext {
	public const string linux_default_dictionary_path = "/usr/share/dict";
	public const string im_name = "Lexicim";
	static string[] words;
	
	public override void get_preedit_string (out string str, out Pango.AttrList attrs, out int pos) {
		str = "";
		pos = 0;
		attrs = new Pango.AttrList ();
		if (null == words){ return; }
		
		unowned string? surrounding = null;
		int surrounding_position = 0;
		bool must_free_surrounding = get_surrounding (out surrounding, out surrounding_position);
		string token = get_token (surrounding, surrounding_position);
		
		if (2 < token.length) {
			str = "meh";
			pos = 0;
		}
		
		stdout.printf ("Using preedit string '%s' for surrounding '%s'\n", str, surrounding);
		
		if (must_free_surrounding){ GLib.free ((void*)surrounding); }
	}// get_preedit_string
	
	public override bool filter_keypress (Gdk.EventKey event) {
		bool handled = false;
		
		if (Gdk.EventType.KEY_PRESS == event.type) {
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
				break;
			}
			stdout.printf("Committing %s\n", commit_string);
			commit (commit_string);
			preedit_changed ();
		}
		
		return handled;
	}// filter_keypress
	
	static string get_token (string surrounding, int position) {
		string token = "";
		string tmp = "";
		stdout.printf ("Searching for token in '%s:%d'\n", surrounding, position);
		
		if (0 < position && surrounding[position-1].isalpha ()) {
			token = surrounding.replace ("[^\\w]", " ");
			tmp = token.rchr (position-1, ' ');
			if (null != tmp) { token = tmp.strip(); }
			token = token.split(" ", 2)[0];
		} else {
			stdout.printf("Invalid char: '%c' at %d\n", (char)surrounding[position], position);
		}
		
		return token;
	}// get_token
	
	public static void load_dictionary(string language, string path = linux_default_dictionary_path) {
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
			stdout.printf("%s: Dictionary %s loaded.\n", im_name, language);
		}
	}// load_dictionary
	
	public string lookup (string token) {
		return token;
	}// lookup
}
