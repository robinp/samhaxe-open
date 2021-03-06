/*
   Title: Optparse.hx
      Command line argument parsing.
*/


/*
   Anonymous: ReaderResult
      
      Result of some reader function.
*/
typedef ReaderResult = {
   /*
      Variable: value
         The value read by a reader function.
   */ 
   value: Dynamic,
   
   /*
      Variable: advance
         
         How many parameters has been parsed by the reader function.
   */
   advance: Int
}

/*
   Section: Types

   Typedef: OptionReader
      
      Prototype of a reader function.

   > Array<String> -> Int -> ReaderResult;
*/
typedef OptionReader = Array<String> -> Int -> ReaderResult;

/*
   Typedef: OptionWriter
      
      Prototype of a writer function.

   > Dynamic -> String -> Dynamic -> Void
*/
typedef OptionWriter = Dynamic -> String -> Dynamic -> Void;

typedef OptionHandler = {
   field: String,
   reader: OptionReader,
   writer: OptionWriter
}

typedef OptionHelp = {
   short: String,
   long: String,
   help: String,
   help_arg: String
}

/*
   Class: OptparseException
   
      Exception class thrown by <Optparse>
*/
class OptparseException {
   var message: String;
   var arg: String;
   var arg_pos: Int;
   
   /*
      Constructor: new
         
         Constructor

      Parameters:
         
         message - the exception message.
         arg     - the argument where the exception occured.
         arg_pos - the position of the argument in argument list.
   */
   
   public function new(message: String, arg: String, arg_pos: Int) {
      this.message = message;
      this.arg = arg;
      this.arg_pos = arg_pos;
   }

   /*
      Function: toString
      
         Converts the exception to a string.

      Returns:
         
         The string representation of the exception.
   */
   
   public function toString() {
      return message + " (on argument '" + arg + "' at argument position " + arg_pos + ")";
   }
}

/*
   Class: Optparse
   
      Command line argument parsing class.
*/

class Optparse {
   var opt_handler: Hash<OptionHandler>;
   var opt_help: Array<OptionHelp>;

   /*
      Constructor: new
         
         Constructor.
   */
   public function new() {
      opt_handler = new Hash<OptionHandler>();
      opt_help = new Array<OptionHelp>();
   }

   /*
      Function: addOption

         Adds a new command line option to the parser.

      Parameters:
         
         short - the short version of the command line option. Can be null if no short version is required. (Example: "-h")
         long - the long version of the command line option. Can be null if no long version is required. (Example: "--help")
         field - the name of the field which will hold the parsed argument value
         reader - the option reader function which will parse the command line option and it's arguments (if there are any)
         writer - the option writer function which will store the value parsed by the reader (or any other value if necessary)
         help - the help text for the option. It will be included in the help message generated by <getHelp>. Can be omitted.
         help_arg - the format description for the argument(s) of the command line option. Can be omitted.
         
   */
   public function addOption(short: String, long: String, field: String, reader: OptionReader, writer: OptionWriter, ?help: String, ?help_arg: String) {
      var handler: OptionHandler = { 
         field: field,
         reader: reader,
         writer: writer,
      };

      if(short != null && short.length > 0)
         opt_handler.set(short, handler);

      if(long != null && long.length > 0)
         opt_handler.set(long, handler);

      opt_help.push({
         short: short,
         long: long,
         help: help,
         help_arg: help_arg
      });
   }

   /*
      Function: parse

         Parses the command line arguments according to the previously specified options by <addOption>.

      Parameters:
         
         options - the object holding all the option fields
         args - the array of command line arguments
         start - the start index of parsing

      Returns:
         
         The index of the command line argument which cannot be parsed.
         
   */
   public function parse(options: Dynamic, args: Array<String>, start: Int = 0): Int {
      var i = start;

      while(i < args.length) {
         var opt = args[i];

         if(opt.length == 0)
            continue;

         if(opt.charAt(0) != "-")
            return i;
            
         var h: OptionHandler = opt_handler.get(opt);
         if(h == null)
            throw new OptparseException("Unknown option", opt, i);

         var read_result = h.reader(args, i);
         if(read_result.advance == -1)
            break;
         
         h.writer(options, h.field, read_result.value);
         i += read_result.advance;
      }

      return i;
   }

   /*
      Function: getHelp

         Generates option usage help from the previously specified help and help_arg paramteres in <addOption>.

      Returns:
         
         The generated help as a String.
   */
   public function getHelp(): StringBuf {
      var b = new StringBuf();

      opt_help.sort(function(a: Dynamic, b: Dynamic) {
         if(a.short == null && b.short != null) {
            return 1;

         } else if(a.short != null && b.short == null) {
            return -1;

         } else if(a.short != null && b.short != null) {
            if(a.short < b.short)
               return -1;
            else if(a.short > b.short)
               return 1;
            else
               return 0;
         }
 
         if(a.long == null && b.long != null) {
            return 1;

         } else if(a.long != null && b.long == null) {
            return -1;

         } else if(a.long != null && b.long != null) {
            if(a.long < b.long)
               return -1;
            else if(a.long > b.long)
               return 1;
            else
               return 0;
         }
        
         return 0;
      });

      b.add("Options:\n");

      for(opt in opt_help) {
         b.add("    ");
         if(opt.short != null) {
            b.add(opt.short);

            if(opt.help_arg != null)
               b.add(" " + opt.help_arg);

            if(opt.long != null)
               b.add(", " + opt.long);
            
            if(opt.help_arg != null)
               b.add(" " + opt.help_arg);

         } else if(opt.long != null) {
            b.add(opt.long);
            
            if(opt.help_arg != null)
               b.add(" " + opt.help_arg);
         }

         if(opt.help != null)
            b.add("\n           " + opt.help);

         b.add("\n");
      }

      return b;
   }

   /*
      Group: Reader functions
      
      Function: readerNull
      
         Null option reader. Used for options without arguments.

      Parameters:
         
         args - the array of command line arguments
         act - the index of actually parsed argument

      Returns:
         
         value - null
         advance - 1
   */
   public static function readerNull(args: Array<String>, act: Int): ReaderResult {
      return {
         value: null,
         advance: 1
      };
   }

   /*
      Function: readerString
      
         String option reader. Used for options with exactly one argument.
      
      Parameters:
         
         args - the array of command line arguments
         act - the index of actually parsed argument

      Returns:

         value - the argument as a String
         advance - 2
   */
   public static function readerString(args: Array<String>, act: Int): ReaderResult {
      if(act < args.length - 1)
         return {
            value: args[act + 1],
            advance: 2
         };

      throw new OptparseException("The " + args[act] + " option needs an argument!", args[act], act);
   }
   
   /*
      Function: readerInt
      
         Integer option reader. Used for options with exactly one integer argument.

      Parameters:
         
         args - the array of command line arguments
         act - the index of actually parsed argument

      Returns:
         
         value - the argument as an Int
         advance - 2

      Throws:

         <OptparseException> if the argument is missing or cannot be converted to Int.
   */
   public static function readerInt(args: Array<String>, act: Int): ReaderResult {
      if(act >= args.length - 1)
         throw new OptparseException("The " + args[act] + " option needs an argument!", args[act], act);

      var r_int = ~/^[+-]*(([0-9]+)|(0x[0-9a-fA-F]+))$/;
      if(!r_int.match(args[act + 1]))
         throw new OptparseException("The " + args[act] + " option needs an integer argument('" + args[act + 1] + "' has given)!", args[act], act);
        
      return {
         value: Std.parseInt(args[act + 1]),
         advance: 2
      };
   }

   /*
      Function: readerFloat
      
         Float option reader. Used for options with exactly one floating point argument.

      Parameters:
         
         args - the array of command line arguments
         act - the index of actually parsed argument

      Returns:
         
         value - the argument as a Float
         advance - 2

      Throws:

         <OptparseException> if the argument is missing or cannot be converted to Float.
   */
   public static function readerFloat(args: Array<String>, act: Int): ReaderResult {
      if(act >= args.length - 1)
         throw new OptparseException("The " + args[act] + " option needs an argument!", args[act], act);
        
      var r_float = ~/^[+-]*[0-9]+(\.[0-9]*)?$/;
      if(!r_float.match(args[act + 1]))
         throw new OptparseException("The " + args[act] + " option needs a floating point argument('" + args[act + 1] + "' has given)!", args[act], act);
         
      return {
         value: Std.parseFloat(args[act + 1]),
         advance: 2
      };
   }

   /*
      Function: readerKVArray
      
         Key/value pair list option reader. Used for options with a list of key/value pairs argument.
         The key/value pairs are in the following format:

         > key[=value][:key[=value]...]

         Values can be omitted along with equal sign.

      Parameters:
         
         args - the array of command line arguments
         act - the index of actually parsed argument

      Returns:
         
         value - the argument as an Array<{key: String, value: String}>
         advance - 2 (the whole key/value list is one string without spaces)

      Throws:

         <OptparseException> if the argument is missing or the one of the key/value pairs has an invalid format.
   */
   public static function readerKVArray(args: Array<String>, act: Int): ReaderResult {
      if(act >= args.length - 1)
         throw new OptparseException("The " + args[act] + " option needs an argument!", args[act], act);

      var a = new Array<{key: String, value: String}>();
      var pairs = args[act + 1].split(":");
      for(p in pairs) {
         var kv = p.split("=");

         switch(kv.length) {
            case 1:
               a.push({key: kv[0], value: null});

            case 2:
               a.push({key: kv[0], value: kv[1]});

            default:
               throw new OptparseException("Invalid key=value pair in argument of option " + args[act], args[act], act);
         }
      }

      return {
         value: a,
         advance: 2
      };
   }

   /*
      Group: Writer functions

      Function: writerNull
         
         Null option writer. Used when the processed option doesn't have any argument or when the previously parsed argument doesn't need to be stored.

      Parameters:
         
         options - the object holding all the option fields
         field - the name of the field to store value in
         value - the previously parsed value to be stored
      
   */
   public static function writerNull(options: Dynamic, field: String, value: Dynamic) {
   }
   
   /*
      Function: writerStore
      
         Store option writer. Stores the previously parsed argument into the specified option field.
   */
   public static function writerStore(options: Dynamic, field: String, value: Dynamic) {
      Reflect.setField(options, field, value);
   }

   /*
      Function: writerStoreTrue
      
         True boolean value option writer. Stores true into the specified field as a Bool.

      Parameters:

         options - the object holding all the option fields
         field - the name of the field to store value in
         value - the previously parsed value to be stored

      Field requirements:

         - Has to be Bool type.
   */
   public static function writerStoreTrue(options: Dynamic, field: String, value: Dynamic) {
      Reflect.setField(options, field, true);
   }

   /*
      Function: writerStoreFalse
      
         False boolean value option writer. Stores false into the specified field as a Bool.

      Parameters:

         options - the object holding all the option fields
         field - the name of the field to store value in
         value - the previously parsed value to be stored
      
      Field requirements:

         - Has to be Bool type.
   */
   public static function writerStoreFalse(options: Dynamic, field: String, value: Dynamic) {
      Reflect.setField(options, field, false);
   }
   
   /*
      Function: writerIncrement
      
         Increment option writer. Increments the specified field by one.

      Parameters:

         options - the object holding all the option fields
         field - the name of the field to store value in
         value - the previously parsed value to be stored
      
      Field requirements:

         - Has to be Int or Float type.
   */
   public static function writerIncrement(options: Dynamic, field: String, value: Dynamic) {
      var new_value = Reflect.field(options, field) + 1;
      Reflect.setField(options, field, new_value);
   }

   /*
      Function: writerAppend
      
         Array append option writer. Appends the previously parsed argument to the specified array field.

      Parameters:

         options - the object holding all the option fields
         field - the name of the field to store value in
         value - the previously parsed value to be stored
      
      Field requirements:

         - Has to be Array type.
   */
   public static function writerAppend(options: Dynamic, field: String, value: Dynamic) {
      var field_obj = Reflect.field(options, field);
      field_obj.push(value);
   }

   /*
      Function: makeWriterStoreConst
      
         Constant option writer creator. Returns a writer function which stores the specified value into the option field.

      Parameters:

         user_const - the value to be stored

      Returns:

         The appropriate option writer function.
   */

   public static function makeWriterStoreConst(user_const: Dynamic): Dynamic -> String -> Dynamic -> Void {
      return function(options: Dynamic, field: String, value: Dynamic) {
         Reflect.setField(options, field, user_const);
      }
   }

   }
