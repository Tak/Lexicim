using GLib;
using Gtk;

public class Lexicim.Lexicim: Gtk.IMContext {
	public override void get_preedit_string (out string str, out Pango.AttrList attrs, out int pos) {
		str = "blah";
		attrs = new Pango.AttrList ();
		pos = 0;
	}// get_preedit_string
}
