package;

import haxe.ds.StringMap;

/**
 * Command-line argument parser
 * 
 * Supports multiple argument formats:
 * - Flags: --flag or -f
 * - Key-value pairs: --key=value or --key value
 * - Positional arguments
 * 
 * Example usage:
 * ```
 * var args = new Args();
 * if (args.has("--help")) {
 *     trace("Help requested");
 * }
 * var width = args.getInt("--width", 800);
 * var filename = args.get("--file");
 * ```
 */
class Args {
    
    private var flags:StringMap<Bool>;
    private var params:StringMap<String>;
    private var positional:Array<String>;
    private var rawArgs:Array<String>;
    
    public function new() {
        flags = new StringMap<Bool>();
        params = new StringMap<String>();
        positional = [];
        rawArgs = Sys.args();
        parse();
    }
    
    /**
     * Parse the command-line arguments
     */
    private function parse():Void {
        var i = 0;
        while (i < rawArgs.length) {
            var arg = rawArgs[i];
            
            // Check for --key=value format
            if (arg.indexOf("=") != -1) {
                var parts = arg.split("=");
                var key = parts[0];
                var value = parts.slice(1).join("="); // Handle values with = in them
                params.set(key, value);
                i++;
                continue;
            }
            
            // Check for flags (--flag or -f)
            if (StringTools.startsWith(arg, "--") || StringTools.startsWith(arg, "-")) {
                // Check if next argument is a value (doesn't start with - or --)
                if (i + 1 < rawArgs.length && !StringTools.startsWith(rawArgs[i + 1], "-")) {
                    params.set(arg, rawArgs[i + 1]);
                    i += 2;
                } else {
                    // It's a flag
                    flags.set(arg, true);
                    i++;
                }
            } else {
                // Positional argument
                positional.push(arg);
                i++;
            }
        }
    }
    
    /**
     * Check if a flag exists
     * @param name Flag name (e.g., "--help" or "-h")
     * @return True if the flag was provided
     */
    public function has(name:String):Bool {
        return flags.exists(name);
    }
    
    /**
     * Check if a parameter exists
     * @param name Parameter name (e.g., "--width")
     * @return True if the parameter was provided
     */
    public function hasParam(name:String):Bool {
        return params.exists(name);
    }
    
    /**
     * Get a string parameter value
     * @param name Parameter name
     * @param defaultValue Default value if parameter doesn't exist
     * @return The parameter value or default
     */
    public function get(name:String, ?defaultValue:String):String {
        if (params.exists(name)) {
            return params.get(name);
        }
        return defaultValue;
    }
    
    /**
     * Get an integer parameter value
     * @param name Parameter name
     * @param defaultValue Default value if parameter doesn't exist or can't be parsed
     * @return The parameter value as an integer or default
     */
    public function getInt(name:String, defaultValue:Int = 0):Int {
        if (params.exists(name)) {
            var value = params.get(name);
            var parsed = Std.parseInt(value);
            return parsed != null ? parsed : defaultValue;
        }
        return defaultValue;
    }
    
    /**
     * Get a float parameter value
     * @param name Parameter name
     * @param defaultValue Default value if parameter doesn't exist or can't be parsed
     * @return The parameter value as a float or default
     */
    public function getFloat(name:String, defaultValue:Float = 0.0):Float {
        if (params.exists(name)) {
            var value = params.get(name);
            var parsed = Std.parseFloat(value);
            return Math.isNaN(parsed) ? defaultValue : parsed;
        }
        return defaultValue;
    }
    
    /**
     * Get a boolean parameter value
     * Accepts: true/false, yes/no, 1/0, on/off (case insensitive)
     * @param name Parameter name
     * @param defaultValue Default value if parameter doesn't exist or can't be parsed
     * @return The parameter value as a boolean or default
     */
    public function getBool(name:String, defaultValue:Bool = false):Bool {
        if (params.exists(name)) {
            var value = params.get(name).toLowerCase();
            return switch (value) {
                case "true", "yes", "1", "on": true;
                case "false", "no", "0", "off": false;
                default: defaultValue;
            }
        }
        // Check if it's a flag
        if (flags.exists(name)) {
            return true;
        }
        return defaultValue;
    }
    
    /**
     * Get positional argument by index
     * @param index Index of the positional argument
     * @return The positional argument or null if out of bounds
     */
    public function getPositional(index:Int):String {
        if (index >= 0 && index < positional.length) {
            return positional[index];
        }
        return null;
    }
    
    /**
     * Get all positional arguments
     * @return Array of positional arguments
     */
    public function getPositionalArgs():Array<String> {
        return positional.copy();
    }
    
    /**
     * Get the number of positional arguments
     * @return Count of positional arguments
     */
    public function getPositionalCount():Int {
        return positional.length;
    }
    
    /**
     * Get all raw arguments as provided to the program
     * @return Array of all raw arguments
     */
    public function getRawArgs():Array<String> {
        return rawArgs.copy();
    }
    
    /**
     * Print all parsed arguments (useful for debugging)
     */
    public function dump():Void {
        trace("=== Command Line Arguments ===");
        trace("Flags:");
        for (key in flags.keys()) {
            trace('  $key');
        }
        trace("Parameters:");
        for (key in params.keys()) {
            trace('  $key = ${params.get(key)}');
        }
        trace("Positional:");
        for (i in 0...positional.length) {
            trace('  [$i] = ${positional[i]}');
        }
        trace("==============================");
    }
}
