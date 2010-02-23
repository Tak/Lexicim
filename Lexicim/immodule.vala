using GLib;
using Gtk;

namespace Lexicim {

	const string context_id = "LexicimInputModule_v001";
	const string context_name = "Lexicim";
	const string locales = "/usr/share/locales";
	
	[ModuleInit]
	[CCode(cname="im_module_init")]
	public static void init (TypeModule module) {
	}// init
	
	[CCode(cname="im_module_exit")]
	public static void exit () {
	}// exit
	
	[CCode(cname="im_module_list")]
	public static void list_modules (out IMContextInfo?[] contexts) {
		contexts = new IMContextInfo[1];
		IMContextInfo blah = { context_id, context_name, context_name, locales, "" };
		contexts[0] = blah;
	}// list_modules
	
	[CCode(cname="im_module_create")]
	public static IMContext? create_module (string for_context_id) {
		if (for_context_id == context_id) {
			return new Lexicim ();
		}
		return null;
	}// create_module
}
