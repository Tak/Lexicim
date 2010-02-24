using GLib;
using Gtk;

namespace Lexicim {
	// Mandatory methods for Gtk+ input module registration

	const string context_id = "LexicimInputModule_v001";
	const string locales = "/usr/share/locales";
	
	/**
	 * Initialize the input module
	 * @param module The TypeModule with which to register.
	 */
	[ModuleInit]
	[CCode(cname="im_module_init")]
	public static void init (TypeModule module) {
		Lexicim.load_dictionary ("american-english");
	}// init
	
	/**
	 * Cleanup the input module
	 */
	[CCode(cname="im_module_exit")]
	public static void exit () {
	}// exit
	
	/**
	 * List the input modules provided by this library
	 * @param contexts The context info for the available input modules will be stored here
	 */
	[CCode(cname="im_module_list")]
	public static void list_modules (out IMContextInfo?[] contexts) {
		contexts = new IMContextInfo[1];
		IMContextInfo blah = { context_id, Lexicim.im_name, Lexicim.im_name, locales, "" };
		contexts[0] = blah;
	}// list_modules
	
	/**
	 * Instantiate an input module
	 * @param for_context_id The context ID of the input module to be instantiated
	 * @return A new input module instance, 
	 * or null if an invalid context ID is given
	 */
	[CCode(cname="im_module_create")]
	public static IMContext? create_module (string for_context_id) {
		if (for_context_id == context_id) {
			return new Lexicim ();
		}
		return null;
	}// create_module
}
