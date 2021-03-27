module compiler.typecheck;

import compiler.symbols;
import std.conv : to;
import std.string;
import std.stdio;

/**
* The Parser only makes sure syntax
* is adhered to (and, well, partially)
* as it would allow string+string
* for example
*
*/
public final class TypeChecker
{
    private Program program;

    this(Program program)
    {
        this.program = program;

        writeln("Got globals: "~to!(string)(program.getAllOf(new Variable(null, null), program.getStatements())));
        writeln("Got functions: "~to!(string)(program.getAllOf(new Function(null, null, null, null), program.getStatements())));
        writeln("Got classes: "~to!(string)(program.getAllOf(new Clazz(null),program.getStatements())));
        
        // nameResolution;
        // writeln("Res:",isValidEntity(program.getStatements(), "clazz1"));
        // writeln("Res:",isValidEntity(program.getStatements(), "clazz_2_1.clazz_2_2"));

        //process();
    }

    /**
    * List of currently declared variables
    */
    private Entity[] declaredVars;



    /**
    * Initialization order
    */

    /**
    * Example:
    *
    * 
    * int a;
    * int b = a;
    * int c = b;
    * Reversing must not work
    *
    * Only time it can is if the path is to something in a class as those should
    * be initialized all before variables
    */
    private void process(Statement[] statements)
    {
        /* Go through each entity and check them */

        /* TODO: Starting with x, if `int x = clacc.class.class.i` */
        /* TODO: Then we getPath from the assignment aexpressiona nd eval it */
        /**
        * TODO: The variable there cannot rely on x without it being initted, hence 
        * need for global list of declared variables
        */
    }

    /* Test name resolution */
    unittest
    {
        //assert()
    }

    /* TODO: We need a duplicate detector, maybe do this in Parser, in `parseBody` */

    /* Path: clazz_2_1.class_2_2 */
    public Entity isValidEntity(Statement[] startingPoint, string path)
    {   /* The entity found with the matching name at the end of the path */
        // Entity foundEntity;

        /* Go through each Statement and look for Entity's */
        foreach(Statement curStatement; startingPoint)
        {
            /* Only look for Entitys */
            if(cast(Entity)curStatement !is null)
            {
                /* Current entity */
                Entity curEntity = cast(Entity)curStatement;

                /* Make sure the root of path matches current entity */
                string[] name = split(path, ".");

                /* If root does not match current entity, skip */
                if(cmp(name[0], curEntity.getName()) != 0)
                {
                    continue;
                }

                // writeln("warren g had to regulate");


                /**
                * Check if the name fully matches this entity's name
                *
                * If so, return it, a match has been found
                */
                if(cmp(path, curEntity.getName()) == 0)
                {
                    return curEntity;
                }
                /**
                * Or recurse
                */
                else
                {
                    string newPath = path[indexOf(path, '.')+1..path.length];
                    
                    /* In this case it must be some sort of container */
                    if(cast(Container)curEntity)
                    {
                        Container curContainer = cast(Container)curEntity;

                        /* Get statements */
                        Statement[] containerStatements = curContainer.getStatements();

                        /* TODO: Consider accessors? Here, Parser, where? */

                        return isValidEntity(containerStatements, newPath);
                    }
                    /* If not, error , semantics */
                    else
                    {
                        return null;
                    }
                }
            }
        }


        return null;
    }

    /**
    * This function will walk, recursively, through
    * each Statement at the top-level and generate
    * names of declared items in a global array
    *
    * This is top-level, iterative then recursive within
    * each iteration
    *
    * The point of this is to know of all symbols
    * that exist so that we can do a second pass
    * and see if symbols in use (declaration does
    * not count as "use") are infact valid references
    */
    public void nameResolution()
    {
        string[] names;

        foreach(Statement statement; program.getAllOf(new Statement(), program.getStatements()))
        {
            /* TODO: Add container name */
            /* TODO: Make sure all Entity type */
            string containerName = (cast(Entity)statement).getName();
            names ~= containerName;
            string[] receivedNameSet = resolveNames(containerName, statement);
            names ~= receivedNameSet;
        }
    }

    private string[] resolveNames(string root, Statement statement)
    {
        /* If the statement is a variable then return */
        if(typeid(statement) == typeid(Variable))
        {
            return null;
        }
        /* If it is a class */
        else if(typeid(statement) == typeid(Clazz))
        {
            /* Get class's identifiers */
            
        }
        return null;
    }


    public void check()
    {
        checkDuplicateTopLevel();

        /* TODO: Process globals */
        /* TODO: Process classes */
        /* TODO: Process functions */
    }

    

    /**
    * Ensures that at the top-level there are no duplicate names
    */
    private bool checkDuplicateTopLevel()
    {
        import misc.utils;
        import compiler.parser : Parser;

        /* List of names travsersed so far */
        string[] names;

        /* Add all global variables */
        foreach(Variable variable; program.getAllOf(new Variable(null, null), program.getStatements()))
        {
            string name = variable.getName();

            if(isPresent(names, name))
            {
                Parser.expect("Bruh duplicate var"~name);
            }
            else
            {
                names ~= variable.getName();
            }
        }

        return true;
    }
}

unittest
{
    /* TODO: Add some unit tests */
    import std.file;
    import std.stdio;
    import compiler.lexer;
    import compiler.parser;

    // isUnitTest = true;

    string sourceFile = "source/tlang/testing/basic1.t";
    
        File sourceFileFile;
        sourceFileFile.open(sourceFile); /* TODO: Error handling with ANY file I/O */
        ulong fileSize = sourceFileFile.size();
        byte[] fileBytes;
        fileBytes.length = fileSize;
        fileBytes = sourceFileFile.rawRead(fileBytes);
        sourceFileFile.close();

    

        /* TODO: Open source file */
        string sourceCode = cast(string)fileBytes;
        // string sourceCode = "hello \"world\"|| ";
        //string sourceCode = "hello \"world\"||"; /* TODO: Implement this one */
        // string sourceCode = "hello;";
        Lexer currentLexer = new Lexer(sourceCode);
        currentLexer.performLex();
        
      
        Parser parser = new Parser(currentLexer.getTokens());

        Program program = parser.parse();

        TypeChecker typeChecker = new TypeChecker(program);
        typeChecker.check();

        /* Test first-level resolution */
        assert(cmp(typeChecker.isValidEntity(program.getStatements(), "clazz1").getName(), "clazz1")==0);

        /* Test n-level resolution */
        assert(cmp(typeChecker.isValidEntity(program.getStatements(), "clazz_2_1.clazz_2_2").getName(), "clazz_2_2")==0);
        assert(cmp(typeChecker.isValidEntity(program.getStatements(), "clazz_2_1.clazz_2_2.j").getName(), "j")==0);
        assert(cmp(typeChecker.isValidEntity(program.getStatements(), "clazz_2_1.clazz_2_2.clazz_2_2_1").getName(), "clazz_2_2_1")==0);
        assert(cmp(typeChecker.isValidEntity(program.getStatements(), "clazz_2_1.clazz_2_2").getName(), "clazz_2_2")==0);

        /* Test invalid access to j treating it as a Container (whilst it is a Variable) */
        assert(typeChecker.isValidEntity(program.getStatements(), "clazz_2_1.clazz_2_2.j.p") is null);

        
}