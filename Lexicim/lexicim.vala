// 
//  lexicim.vala
//  
//  Author:
//       Levi Bard <taktaktaktaktaktaktaktaktaktak@gmail.com>
//  
//  Copyright (c) 2010 Levi Bard
// 
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU Lesser General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
// 
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU Lesser General Public License for more details.
// 
//  You should have received a copy of the GNU Lesser General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.

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
	
	// Cached items for get_preedit_string
	string preedit;
	Pango.AttrList preeditAttrs;
	int preeditPos;
	
	public Lexicim () {
		lastMatchedIndex = -1;
		preedit = "";
		preeditAttrs = new Pango.AttrList ();
		preeditAttrs.insert (Pango.attr_style_new (Pango.Style.ITALIC));
		preeditPos = 0;
	}// constructor
	
	/**
	 * Gets the current completion suggestion
	 * @see Gtk.IMContext.get_preedit_string
	 */
	public override void get_preedit_string (out string str, out Pango.AttrList attrs, out int pos) {
		if (enabled) {
			str = preedit;
			attrs = preeditAttrs;
			pos = preeditPos;
		} else {
			str = "";
			pos = 0;
			attrs = new Pango.AttrList ();
		}
	}// get_preedit_string
	
	/**
	 * Sets the preedit string to the remainder of the first string 
	 * to match the current token.
	 */
	void first_preedit_string () {
		string token = get_current_token ();
		if (2 < token.length) {
			preedit = lookup (token).offset (token.length);
		} else {
			preedit = "";
		}// only do lookups on 3+-letter words
		
		preedit_changed ();
	}// first_preedit_string
	
	/**
	 * Sets the preedit string to the next valid completion.
	 */
	void next_preedit_string () {
		if (0 > lastMatchedIndex || words.length-1 <= lastMatchedIndex) {
			first_preedit_string ();
			return;
		}
		
		string token = get_current_token ();
		int matchedCharacters = match_characters (token, words[lastMatchedIndex]);
		if (match_characters (token, words[lastMatchedIndex+1]) < matchedCharacters ||
		    token.length < matchedCharacters) {
			// End of equally good matches
			first_preedit_string ();
			return;
		} else {
			++lastMatchedIndex;
			preedit = words[lastMatchedIndex].offset (token.length);
		}// check validity of next word
		
		preedit_changed ();
	}// next_preedit_string
	
	/**
	 * Sets the preedit string to the previous valid completion.
	 */
	void previous_preedit_string () {
		if (1 > lastMatchedIndex) {
			first_preedit_string ();
			return;
		}
		
		string token = get_current_token ();
		int matchedCharacters = match_characters (token, words[lastMatchedIndex]);
		if (match_characters (token, words[lastMatchedIndex-1]) < matchedCharacters ||
		    token.length < matchedCharacters) {
			// End of equally good matches
			first_preedit_string ();
			return;
		} else {
			--lastMatchedIndex;
			preedit = words[lastMatchedIndex].offset (token.length);
		}// check validity of next word
		
		preedit_changed ();
	}// previous_preedit_string
	
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
				break;
			case Gdk.Key_BackSpace:
			case Gdk.Key_Delete:
			case Gdk.Key_KP_Delete:
				// Clear completion on backspace/delete
				enabled = false;
				reset ();
				break;
			case Gdk.Key_Left:
			case Gdk.Key_leftarrow:
			case Gdk.Key_KP_Left:
				// Cycle backward through completions
				previous_preedit_string ();
				handled = enabled;
				break;
			case Gdk.Key_Right:
			case Gdk.Key_rightarrow:
			case Gdk.Key_KP_Right:
				// Cycle forward through completions
				next_preedit_string ();
				handled = enabled;
				break;
			case Gdk.Key_KP_Space:
			case Gdk.Key_space:
				// Special-case space input - this was necessary for xchat
				commit (commit_string);
				reset ();
				handled = true;
				break;
			default:
				// Commit and pass through printable keypresses
				enabled = event.str[0].isprint ();
				if (enabled) {
					commit (commit_string);
					first_preedit_string ();
					handled = true;
				} else {
					reset ();
				}
				break;
			}
		} else if (Gdk.EventType.KEY_RELEASE == event.type && 
		           Gdk.Key_Tab == event.keyval) {
			// Special-case tab release - this was necessary for gedit
			enabled = false;
			reset ();
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
		preedit = "";
		preedit_changed ();
	}// reset
	
	/**
	 * Gets the alphabetic token around the current cursor position.
	 * @return The current token, or empty string
	 */
	string get_current_token () {
		// Get the completion token
		unowned string? surrounding = null;
		int surrounding_position = 0;
		bool must_free_surrounding = get_surrounding (out surrounding, out surrounding_position);
		if (null == surrounding){ return ""; }
		
		string token = get_token (surrounding, surrounding_position);
		
		// Goofy api
		if (must_free_surrounding){ GLib.free ((void*)surrounding); }
		
		return token;
	}// get_current_token
	
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
	string lookup (string token) {
		int matchedCharacters = 0,
		    tmp = 0,
		    firstIndex = 0;
		
		stdout.printf("Looking up %s\n", token);
		
		if (indices.contains (token[0])) {
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
		}// if we have words beginning with the same letter as token
		
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
