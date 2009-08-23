/*
   Title: SymbolRegistry.hx
*/

/*
   Interface: SymbolRegistry
      Keeps track of symbol class names generated by import modules.
*/
interface SymbolRegistry {
   /*
      Function: symbolExists
         Check if a given symbol exists in the registry.

      Parameters:
         symbol - The symbol name to check

      Retirns:
         false - if the symbol doesn't exist in the registry
         true - if the symbol already exists in the registry
   */
   function symbolExists(symbol: String): Bool;

   /*
      Function: addSymbol
         Adds a symbol to the registry.

      Parameters:
         cid - the character ID assigned to the symbol
         symbol - the symbol name
         store - if true then store symbol class in SWF
   */
   function addSymbol(cid: Int, symbol: String, ?store : Bool = true): Void;

   /*
      Function: getSymbolCid
         Returns the character ID for a symbol.

      Parameters:
         symbol - the symbol name

      Returns:
         The character ID for the given symbol.
   */
   function getSymbolCid(symbol: String): Int;

   /*
      Function: getCidSymbol
         Returns the symbol name for a character ID.

      Parameters:
         cid - the character ID

      Returns:
         The symbol name.
   */
   function getCidSymbol(cid: Int): Null<String>;
}
