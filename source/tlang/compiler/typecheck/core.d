module compiler.typecheck.core;

import compiler.symbols.check;
import compiler.symbols.data;
import std.conv : to;
import std.string;
import std.stdio;
import gogga;
import compiler.parsing.core;
import compiler.typecheck.resolution;
import compiler.typecheck.exceptions;
import compiler.symbols.typing.core;

/**
* The Parser only makes sure syntax
* is adhered to (and, well, partially)
* as it would allow string+string
* for example
*
*/
public final class TypeChecker
{
    private Module modulle;

    /* The name resolver */
    private Resolver resolver;

    public Module getModule()
    {
        return modulle;
    }

    this(Module modulle)
    {
        this.modulle = modulle;
        resolver = new Resolver(this);
        /* TODO: Module check?!?!? */
        // initTrees();
    }

    // import compiler.typecheck.visitor;
    // private VTreeNode root;


    // /**
    // * Root of reliance (dependency) tree
    // */
    // import compiler.typecheck.reliance;
    // private RelianceNode relianceRootNode;


    // private void initTrees()
    // {
    //     // root = new VTreeNode(modulle);

    //     /* Create a reliance node with no dependancies for the module */
    //     relianceRootNode = new RelianceNode(modulle);
    // }


    // // private Statement[] visistedStatements;
    // public void visit(VTreeNode level, Statement statement)
    // {
    //     // visistedStatements ~= statement;
    //     level.addChild(new VTreeNode(statement));
    // }

    // public VTreeNode hasVisited(Statement statementInQuestion)
    // {
    //     return root.isInTree(statementInQuestion);
    // }

    /**
    * I guess this should be called rather
    * when processing assignments but I also
    * think we need something like it for
    * class initializations first rather than
    * variable expressions in assignments 
    * (which should probably use some other
    * function to check that then)
    */
    public void dependencyCheck()
    {
        /* Check declaration and definition types */
        checkDefinitionTypes(modulle);

        /* TODO: Implement me */
        checkClassInherit(modulle);


        /**
        * Dependency tree generation
        *
        * Currently this generates a dependency tree
        * just for the module, the tree must be run
        * through after wards to make it
        * non-cyclic
        *
        */
        import compiler.typecheck.dependency;
        DNodeGenerator dNodeGenerator = new DNodeGenerator(this);
        DNode rootNode = dNodeGenerator.generate(); /* TODO: This should make it acyclic */

        /* Print the tree */
        string tree = rootNode.print();
        gprintln(tree);

        /* TODO: Work in progress (NEW!!!) */
        /* Get the action-list (linearised bottom up graph) */
        DNode[] actionList = rootNode.poes;
        doTypeCheck(actionList);

        
        

        /**
        * TODO: What's next?
        *
        * 1. Fetch the tree from the DNodeGenerator
        */

        
    }

    import compiler.typecheck.dependency;
    import std.container.slist;

    import compiler.codegen.instruction;
    private SList!(Instruction) codeQueue;

    public void addInstr(Instruction inst)
    {
        codeQueue.insert(inst);
    }

    public void addInstrB(Instruction inst)
    {
        codeQueue.insertAfter(codeQueue[], inst);
    }

    public Instruction popInstr()
    {
        Instruction poppedInstr;

        if(!codeQueue.empty)
        {
            poppedInstr = codeQueue.front();
            codeQueue.removeFront();
        }
        
        return poppedInstr;
    }
    
    public SList!(Instruction) getCodeQueue()
    {
        return codeQueue;
    }

    /*
    * Prints the current contents of the code-queue
    */
    public void printCodeQueue()
    {
        import std.range : walkLength;
        ulong i = 0;
        foreach(Instruction instruction; codeQueue)
        {
            gprintln(to!(string)(i+1)~"/"~to!(string)(walkLength(codeQueue[]))~": "~instruction.toString());
            i++;
        }
    }


    private SList!(Type) typeStack;


    private void addType(Type typeName)
    {
        typeStack.insertAfter(typeStack[], typeName);
    }

    private Type popType()
    {
        Type typeCur = typeStack.front();
        
        typeStack.removeFront();

        return typeCur;
    }

    public void typeCheckThing(DNode dnode)
    {
        gprintln("typeCheckThing(): "~dnode.toString());

        /* ExpressionDNodes */
        if(cast(compiler.typecheck.expression.ExpressionDNode)dnode)
        {
            compiler.typecheck.expression.ExpressionDNode expDNode = cast(compiler.typecheck.expression.ExpressionDNode)dnode;

            Statement statement = expDNode.getEntity();
            gprintln("Hdfsfdjfds"~to!(string)(statement));

            /* Dependent on the type of Statement */

            if(cast(NumberLiteral)statement)
            {
                /* TODO: For now */

                /**
                * Typechecking
                */
                gprintln("NUMBER LIT");
                addType(getType(modulle, "int"));

                /**
                * Codegen
                */
                ulong i = to!(ulong)((cast(NumberLiteral)statement).getNumber());
                LiteralValue litValInstr = new LiteralValue(i, 4);
                addInstr(litValInstr);
            }
            else if(cast(StringExpression)statement)
            {
                /* TODO: For now */
                // gprintln("STRING LIT");
                // addType(getType(modulle, "int"));
            }
            else if(cast(VariableExpression)statement)
            {
                auto g  = cast(VariableExpression)statement;
                auto gVar = cast(TypedEntity)resolver.resolveBest(g.getContext().getContainer(), g.getName());

                string variableName = resolver.generateName(modulle, gVar);
                
                /* TODO: Above TYpedEntity check */
                /* TODO: still wip the expresison parser */

                /* TODO: TYpe needs ansatz too `.updateName()` call */
                addType(getType(gVar.getContext().getContainer(), gVar.getType()));


                /**
                * Codegen
                *
                * FIXME: Add type info, length
                */
                FetchValueVar fVV = new FetchValueVar(variableName, 4);
                addInstr(fVV);
            }
            // else if(cast()) !!!! Continue here 
            else if(cast(BinaryOperatorExpression)statement)
            {
                BinaryOperatorExpression binOpExp = cast(BinaryOperatorExpression)statement;
                SymbolType binOperator = binOpExp.getOperator();

                /**
                * Typechecking (TODO)
                */

                /**
                * Codegen
                *
                * Retrieve the two Value Instructions
                *
                * They would be placed as if they were on stack
                * hence we need to burger-flip them around (swap)
                */
                Instruction vRhsInstr = popInstr();
                Instruction vLhsInstr = popInstr();
                
                BinOpInstr addInst = new BinOpInstr(vLhsInstr, vRhsInstr, binOperator);
                addInstr(addInst);
            }
        }
        /* VariableAssigbmentDNode */
        else if(cast(compiler.typecheck.variables.VariableAssignmentNode)dnode)
        {
            import compiler.typecheck.variables;
            /* Get the variable's name */
            string variableName;
            VariableAssignmentNode varAssignDNode = cast(compiler.typecheck.variables.VariableAssignmentNode)dnode;
            Variable assignTo = (cast(VariableAssignment)varAssignDNode.getEntity()).getVariable();
            variableName = resolver.generateName(modulle, assignTo);

            /**
            * Codegen
            *
            * 1. Get the variable's name
            * 2. Pop Value-instruction
            * 3. Generate VarAssignInstruction with Value-instruction
            */
            Instruction valueInstr = popInstr();
            VariableAssignmentInstr varAssInstr = new VariableAssignmentInstr(variableName, valueInstr);
            addInstr(varAssInstr);
        }
        else if(cast(compiler.typecheck.variables.ModuleVariableDeclaration)dnode)
        {
            /**
            * Codegen
            *
            * Emit a variable declaration instruction
            */
            Variable variablePNode = cast(Variable)dnode.getEntity();
            string variableName = resolver.generateName(modulle, variablePNode);
            VariableDeclaration varDecInstr = new VariableDeclaration(variableName, 4);

            /* Check if there is a VariableAssignmentInstruction */
            Instruction possibleInstr = popInstr();
            if(possibleInstr !is null)
            {
                VariableAssignmentInstr varAssInstr = cast(VariableAssignmentInstr)possibleInstr;
                if(varAssInstr)
                {
                    /* Check if the assignment is to this variable */
                    if(cmp(varAssInstr.varName, variableName) == 0)
                    {
                        /* If so, re-order (VarDec then VarAssign) */
                        
                        addInstrB(varDecInstr);
                        addInstrB(varAssInstr);
                    }
                    else
                    {
                        /* If not, then no re-order */
                        addInstrB(varAssInstr);
                        addInstrB(varDecInstr);
                    }
                }
                else
                {
                    /* Push it back if not a VariableAssignmentInstruction */
                    
                    addInstr(possibleInstr);
                    addInstrB(varDecInstr);
                    
                }
            }
            

            

            
        }
        /* TODO: ANy statement */
        else if(cast(compiler.typecheck.dependency.DNode)dnode)
        {
            /* TODO: Get the STatement */
            Statement statement = dnode.getEntity();

            gprintln("Poes vavavas");

            /* VariableAssignmentStdAlone */
            if(cast(VariableAssignmentStdAlone)statement)
            {
                VariableAssignmentStdAlone vasa = cast(VariableAssignmentStdAlone)statement;
                string variableName = vasa.getVariableName();

                /**
                * Codegen
                *
                * 1. Get the variable's name
                * 2. Pop Value-instruction
                * 3. Generate VarAssignInstruction with Value-instruction
                */
                Instruction valueInstr = popInstr();
                VariableAssignmentInstr varAssInstr = new VariableAssignmentInstr(variableName, valueInstr);
                

                VariableAssignmentInstr vAInstr = new VariableAssignmentInstr(variableName, valueInstr);
                addInstrB(vAInstr);
            }
        }
        


    }

    
    private void doTypeCheck(DNode[] actionList)
    {
        /* Resource stack */
        SList!(DNode) resStack;

        /* Klaar list */
        /* TODO: Add */

        gprintln("Action list: "~to!(string)(actionList));
        foreach(DNode node; actionList)
        {
            gprintln("Process: "~to!(string)(node));

            /* Print the code queue each time */
            printCodeQueue();

            /**
            * Now depending on thr DNode type we should
            * place ambiguous intems on stack then
            * move on, let the next process then
            * pop the stack and then consume it
            * for checking (typewise we can get 
            * information out of it), then when
            * done we should probably pop-the other
            * guy off and push something that resembles
            * an emmitable onto an EmitStack
            */


            /* will.i.am is a literal cringe */
            typeCheckThing(node);

            // /* If ExpressionDNode then ambiguous */
            // if(cast(compiler.typecheck.expression.ExpressionDNode)node)
            // {
            //     typeCheckThing(node);
            //     // resStack.insertAfter(resStack[], node);
            // }
            // /* If compiler.typecheck.variables.VariableAssignmentNode then amb */
            // else if(cast(compiler.typecheck.variables.VariableAssignmentNode)node)
            // {
            //     typeCheckThing(node);
            //     // resStack.insertAfter(resStack[], node);
            // }
            // /* If compiler.typecheck.variables.VariableAssignmentStdAlone then amb */
            // else if(cast(compiler.typecheck.variables.VariableAssignmentStdAlone)node)
            // {
            //     typeCheckThing(node);
            //     // resStack.insertAfter(resStack[], node);
            // }
            /* Non-ambigous ModuleVarDev */
            // else if(cast(compiler.typecheck.variables.ModuleVariableDeclaration)node)
            // {
            //     /**
            //     * Codegen
            //     *
            //     * Emit a variable declaration instruction
            //     */
            //     Variable variablePNode = cast(Variable)node.getEntity();
            //     string variableName = resolver.generateName(modulle, variablePNode);
            //     VariableDeclaration varDecInstr = new VariableDeclaration(variableName, 4);

            //     /* Check if there is a VariableAssignmentInstruction */
            //     Instruction possibleInstr = popInstr();
            //     if(possibleInstr !is null)
            //     {
            //         VariableAssignmentInstr varAssInstr = cast(VariableAssignmentInstr)possibleInstr;
            //         if(varAssInstr)
            //         {
            //             /* Check if the assignment is to this variable */
            //             if(cmp(varAssInstr.varName, variableName) == 0)
            //             {
            //                 /* If so, re-order (VarDec then VarAssign) */
                            
            //                 addInstrB(varDecInstr);
            //                 addInstrB(varAssInstr);
            //             }
            //             else
            //             {
            //                 /* If not, then no re-order */
            //                 addInstrB(varAssInstr);
            //                 addInstrB(varDecInstr);
            //             }
            //         }
            //         else
            //         {
            //             /* Push it back if not a VariableAssignmentInstruction */
                        
            //             addInstr(possibleInstr);
            //             addInstrB(varDecInstr);
                        
            //         }
            //     }
                

                

                
            // }
            // /* TODO: Remove above smh lmao */
            // else
            // {
            //     typeCheckThing(node);
            // }

            /* TODO: typecheck(node) */
            /* TODO: emit(node) */
        }

        gprintln("<<<<< FINAL CODE QUEUE >>>>>");
        /* Print the code queue each time */
            printCodeQueue();
    }

    /**
    * Given a type as a string this
    * returns the actual type
    *
    * If not found then null is returned
    */
    public Type getType(Container c, string typeString)
    {
        Type foundType;

        /* Check if the type is built-in */
        foundType = getBuiltInType(typeString);

        /* If it isn't then check for a type (resolve it) */
        if(!foundType)
        {
            foundType = cast(Type)resolver.resolveBest(c, typeString);
        }
        
        return foundType;
    }

    private void checkClass(Clazz clazz)
    {
        gprintln("Checking class now...");

        /* TODO: Get all typed entities */
        

        /* TODO: Check things ithin */
        // checkTypedEntitiesTypeNames(clazz);
    }


    

    /**
    * Checks all TypedEntity(s) (so Variables and Functions)
    * such that their types (variable type/return type) are
    * valid type names
    *
    * This is called on a Container
    *
    * TODO: Should we also do expression parsing or rather do another call for that
    * mmmmh
    */
    // private VTreeNode currentNode;
    // private void checkTypedEntitiesTypeNames(Container c)
    // {
    //     /* This VTreeNode */
    //     VTreeNode thisNode;

    //     if(c == modulle)
    //     {
    //         thisNode = root;
    //     }
    //     else
    //     {
    //         /* Create a VTreeNode for this Statement */
    //         assert(cast(Statement)c);
    //         thisNode = new VTreeNode(cast(Statement)c);

    //         gprintln("dsdf");

    //         /* Get my parent's VTreeNode */
    //         /* TODO: This parent of, ah we should make functions be containers, like we gonna need that for constutcor processing etc, and fucntions, mutual recursion there too */
    //         Statement cS = cast(Statement)c;
    //         VTreeNode parentNode = hasVisited(cast(Statement)cS.parentOf());

    //         gprintln("dsdf");
    //         gprintln(parentNode);
    //         gprintln(c);

    //         /* TODO: My grand resolver fuuuuck the parent is not in da tree */
    //         /* TODO: Static classes moment */

    //         /* TODO: We should do this recursively rather, because we exit it is fine technically so the tree will be valid */

    //         /* Child-self to parent VTreeNode */
    //         parentNode.addChild(thisNode);
    //         gprintln("dsdf");


            
    //     }

   
    

    //     TypedEntity[] typedEntities;

    //     foreach (Statement statement; c.getStatements())
    //     {
    //         if (statement !is null && cast(TypedEntity) statement)
    //         {
    //             typedEntities ~= cast(TypedEntity) statement;
    //         }
    //     }

    //     /* Attempt to resolve the types of the variables */
    //     foreach(TypedEntity typedEntity; typedEntities)
    //     {
    //         /* TypedEntity's type */
    //         string typeString = typedEntity.getType();

    //         /* TODO: Resolve type here (either built-in or class type) */
    //         Type type = getType(c, typeString);

    //         /* Make sure type is valid */
    //         if(!type)
    //         {
    //             Parser.expect("Invalid type \""~typeString~"\"");
    //         }

    //         gprintln("Type: "~to!(string)(type));


    //         /* TODO: Visit it (mark it as such) */
    //         VTreeNode thisEntity = new VTreeNode(typedEntity);
            


    //         /* TODO: Check type here */

    //         /* If it is primitive then no further checking */
    //         if(cast(Number)type)
    //         {
    //             /* TODO: Mark it as ready-for-reference */

    //             /* TODO: Expression checking */
    //             thisNode.addChild(thisEntity);
                
    //         }
    //         else
    //         {
    //             /* If it is a Class type */
    //             if(cast(Clazz)type)
    //             {
    //                 Clazz clazzType = cast(Clazz)type;

    //                 /* TODO: Check constructor */

    //                 /* TODO: We need to start marking things */
    //                 /* TODO: Do actual checks here now */

    //                 /* TODO: If the type is of the current class we are in then it is fine? */
    //                 if(clazzType == c)
    //                 {
    //                     gprintln("Container we are in matches type of TypedEdntity being processed");

    //                     /* TODO: In that case mark the entity as fine */
    //                     thisNode.addChild(thisEntity);
    //                     // clazzType.mark();
    //                 }
    //                 /* If the type is visited already (good for rwcuasiev case mutal class references) */
    //                 else if(hasVisited(clazzType))
    //                 {
    //                     /* TODO: This could actually solve the abive too? */
    //                     /* This is basically saying the TypedEntity's type is a CLass that has been visited so we can assume it is safe to add */
    //                     /* We don't wanna visit it again (as stackoevrflow)  from mutaul recursion then */
    //                     thisNode.addChild(thisEntity);
    //                 }
    //                 else
    //                 {
    //                     /* TODO: Also make it fine? mmuutal recusive refernce */
    //                     /* TODO: Got it, we NEED a dependency tree, to know chihs is being processed previosuly */

    //                     /* TODO: Now check this class and follow it's path */
    //                     checkClass(clazzType);
    //                 }

                   
    //             }
    //         }

    //     }


    //     // /**
    //     // * Get all classes
    //     // */
    //     // Clazz[] classes;
    //     // foreach (Statement statement; c.getStatements())
    //     // {
    //     //     if (statement !is null && cast(Clazz) statement)
    //     //     {
    //     //         classes ~= cast(Clazz) statement;
    //     //     }
    //     // }

    //     // /**
    //     // * TODO: Here I am testing on dependeny constrtuction
    //     // * 1. Only for classes
    //     // * 2. Only for their static member (assignment is assumed not to happen)
    //     // */
    //     // foreach(Clazz currentClass; classes)
    //     // {
    //     //     gprintln("DependencyConstruction: Class Container found '"~to!(string)(currentClass)~"'");

    //     //     /* Mark this as reliant on modulle (then) */

    //     //     /* Check recursively */
    //     //     checkClass_DepTest(currentClass);
    //     // }

    // }


    /**
    * Dependency encountering
    *
    * TODO: Move to own module
    // */
    // public string[][string] deps;
    // public void encounter(string entityName, string dependentOn)
    // {
    //     deps[entityName] ~= dependentOn;
    //     gprintln("[Encounter] Entity: \""~entityName~"\" set to be dependent on \""~dependentOn~"\"");
    // }

    // private void checkClass_DepTest(Clazz c)
    // {
    //     /**
    //     * Get all static entities in class
    //     */
    //     Entity[] staticMembers;
    //     foreach (Statement statement; c.getStatements())
    //     {
    //         if (statement !is null && cast(Entity) statement)
    //         {
    //             Entity member = cast(Entity)statement;
    //             if(member.getModifierType() == InitScope.STATIC)
    //             {
    //                 staticMembers ~= cast(Entity) statement;    
    //             }
    //         }
    //     }

    //     gprintln("Static members: "~to!(string)(staticMembers));

    //     /**
    //     * Processes all Class definitions (first, ordered)
    //     * Fucntions and Variables (TODO: I cannot recall that ordering)
    //     */
    //     foreach(Entity staticMember; staticMembers)
    //     {
    //         /**
    //         * Handle static member classes (Class)
    //         */
    //         if(cast(Clazz)staticMember)
    //         {
    //             /* The class must be dependent on the current class */
    //                 gprintln("fdhjdfshjfd");
    //             /* Full path of thing depending on something else */
    //             string dependee = resolver.generateName(modulle, staticMember);

    //             /* Full path of the thing it is dependent on */
    //             string dependency = resolver.generateName(modulle, c);
                
    //             /* Add this to the dependency list fpr the current dependent staticMemberType */
    //             encounter(dependee, dependency);

    //             /* If the static member is a class then apply the logic recursively to it */
    //             Clazz staticMemberClass = cast(Clazz)staticMember;
    //             checkTypedEntitiesTypeNames(staticMemberClass);
    //         }
    //         /**
    //         * Handle static member functions/variables (Function/Variable)
    //         */
    //         else if(cast(TypedEntity)staticMember)
    //         {
    //             /* Typed static member */
    //             TypedEntity typedStaticMember = cast(TypedEntity)staticMember;

    //             /* Get the Type of the member */
    //             Type staticMemberType = getType(c, typedStaticMember.getType());

    //             /* Full path of thing depending on something else */
    //             string dependee = resolver.generateName(modulle, typedStaticMember);

    //             /* Full path of the thing it is dependent on */
    //             string dependency = resolver.generateName(modulle, staticMemberType);
                
    //             /* Add this to the dependency list fpr the current dependent staticMemberType */
    //             encounter(dependee, dependency);
    //         }
    //         else
    //         {
    //             assert(false);
    //         }

    //     }        
    // }



    /* TODO: TYpeEntity check sepeare */
    /* TODO: Parsing within function etc. */

    private void checkDefinitionTypes(Container c)
    {
        /* Check variables and functions (TypedEntities) declarations */
        // checkTypedEntitiesTypeNames(c);

       

        /* Check class inheritance types */
        Clazz[] classes;

        foreach (Statement statement; c.getStatements())
        {
            if (statement !is null && cast(Clazz) statement)
            {
                classes ~= cast(Clazz) statement;
            }
        }
    }

    /**
    * Begins the type checking process
    */
    public void beginCheck()
    {
        /**
        * Make sure there are no name collisions anywhere
        * in the Module with an order of precedence of
        * Classes being declared before Functions and
        * Functions before Variables
        */
        checkContainerCollision(modulle); /* TODO: Rename checkContainerCollision */

        /* TODO: Now that everything is defined, no collision */
        /* TODO: Do actual type checking and declarations */
        dependencyCheck();
    }

    private void checkClassInherit(Container c)
    {
        /* Get all types (Clazz so far) */
        Clazz[] classTypes;

        foreach (Statement statement; c.getStatements())
        {
            if (statement !is null && cast(Clazz) statement)
            {
                classTypes ~= cast(Clazz) statement;
            }
        }

        /* Process each Clazz */
        foreach (Clazz clazz; classTypes)
        {
            /* Get the current class's parent */
            string[] parentClasses = clazz.getInherit();
            gprintln("Class: " ~ clazz.getName() ~ ": ParentInheritList: " ~ to!(
                    string)(parentClasses));

            /* Try resolve all of these */
            foreach (string parent; parentClasses)
            {
                /* Find the named entity */
                Entity namedEntity;

                /* Check if the name is rooted */
                string[] dotPath = split(parent, '.');
                gprintln(dotPath.length);

                /* Resolve the name */
                namedEntity = resolver.resolveBest(c, parent);

                /* If the entity exists */
                if (namedEntity)
                {
                    /* Check if it is a Class, if so non-null */
                    Clazz parentEntity = cast(Clazz) namedEntity;

                    /* Only inherit from class or (TODO: interfaces) */
                    if (parentEntity)
                    {
                        /* Make sure it is not myself */
                        if (parentEntity != clazz)
                        {
                            /* TODO: Add loop checking here */
                        }
                        else
                        {
                            Parser.expect("Cannot inherit from self");
                        }
                    }
                    /* Error */
                else
                    {
                        Parser.expect("Can only inherit from classes");
                    }
                }
                /* If the entity doesn't exist then it is an error */
                else
                {
                    Parser.expect("Could not find any entity named " ~ parent);
                }
            }
        }

        /* Once processing is done, apply recursively */
        foreach (Clazz clazz; classTypes)
        {
            checkClassInherit(clazz);
        }

    }

    private void checkClasses(Container c)
    {
        /**
        * Make sure no duplicate types (classes) defined
        * within same Container
        */
        checkClassNames(c);

        /**
        * Now that everything is neat and tidy
        * let's check class properties like inheritance
        * names
        */
        checkClassInherit(c);
    }

    public Resolver getResolver()
    {
        return resolver;
    }

    /**
    * Given a Container `c` this will check all
    * members of said Container and make sure
    * none of them have a name that conflicts
    * with any other member in said Container
    * nor uses the same name AS the Container
    * itself.
    *
    * Errors are printed when a member has a name
    * of a previously defined member
    *
    * Errors are printed if the memeber shares a
    * name with the container
    *
    * If the above 2 are false then a last check
    * happens to check if the current Entity
    * that just passed these checks is itself a
    * Container, if not, then we do nothing and
    * go onto processing the next Entity that is
    * a member of Container `c` (we stay at the
    * same level), HOWEVER if so, we then recursively
    * call `checkContainer` on said Entity and the
    * logic above applies again
    */
    private void checkContainerCollision(Container c)
    {
        /**
        * TODO: Always make sure this holds
        *
        * All objects that implement Container so far
        * are also Entities (hence they have a name)
        */
        Entity containerEntity = cast(Entity)c;
        assert(containerEntity);

        /**
        * Get all Entities of the Container with order Clazz, Function, Variable
        */
        Entity[] entities = getContainerMembers(c);
        gprintln("checkContainer(C): " ~ to!(string)(entities));

        foreach (Entity entity; entities)
        {
            /**
            * Absolute root Container (in other words, the Module)
            * can not be used
            */
            if(cmp(modulle.getName(), entity.getName()) == 0)
            {
                throw new CollidingNameException(this, modulle, entity, c);
            }
            /**
            * If the current entity's name matches the container then error
            */
            else if (cmp(containerEntity.getName(), entity.getName()) == 0)
            {
                throw new CollidingNameException(this, containerEntity, entity, c);
            }
            /**
            * If there are conflicting names within the current container
            * (this takes precedence into account based on how `entities`
            * is generated)
            */
            else if (findPrecedence(c, entity.getName()) != entity)
            {
                throw new CollidingNameException(this, findPrecedence(c,
                        entity.getName()), entity, c);
            }
            /**
            * Otherwise this Entity is fine
            */
            else
            {
                string fullPath = resolver.generateName(modulle, entity);
                string containerNameFullPath = resolver.generateName(modulle, containerEntity);
                gprintln("Entity \"" ~ fullPath
                        ~ "\" is allowed to be defined within container \""
                        ~ containerNameFullPath ~ "\"");

                /**
                * Check if this Entity is a Container, if so, then
                * apply the same round of checks within it
                */
                Container possibleContainerEntity = cast(Container) entity;
                if (possibleContainerEntity)
                {
                    checkContainerCollision(possibleContainerEntity);
                }
            }
        }

    }


    /**
    * TODO: Create a version of the below function that possibly
    * returns the list of Statement[]s ordered like below but
    * via a weighting system rather
    */
    public Statement[] getContainerMembers_W(Container c)
    {
        /* Statements */
        Statement[] statements;

        /* TODO: Implement me */

        return statements;
    }

    /**
    * Returns container members in order of
    * Clazz, Function, Variable
    */
    private Entity[] getContainerMembers(Container c)
    {
        /* Entities */
        Entity[] entities;

        /* Get all classes */
        foreach (Statement statement; c.getStatements())
        {
            if (statement !is null && cast(Entity) statement)
            {
                entities ~= cast(Entity) statement;
            }
        }

        // /* Get all classes */
        // foreach (Statement statement; c.getStatements())
        // {
        //     if (statement !is null && cast(Clazz) statement)
        //     {
        //         entities ~= cast(Clazz) statement;
        //     }
        // }

        // /* Get all functions */
        // foreach (Statement statement; c.getStatements())
        // {
        //     if (statement !is null && cast(Function) statement)
        //     {
        //         entities ~= cast(Function) statement;
        //     }
        // }

        // /* Get all variables */
        // foreach (Statement statement; c.getStatements())
        // {
        //     if (statement !is null && cast(Variable) statement)
        //     {
        //         entities ~= cast(Variable) statement;
        //     }
        // }

        return entities;

    }

    /**
    * Finds the first occurring Entity with the provided
    * name based on Classes being searched, then Functions
    * and lastly Variables
    */
    public Entity findPrecedence(Container c, string name)
    {
        foreach (Entity entity; getContainerMembers(c))
        {
            /* If we find matching entity names */
            if (cmp(entity.getName(), name) == 0)
            {
                return entity;
            }
        }

        return null;
    }

    /**
    * Starting from a Container c this makes sure
    * that all classes defined within that container
    * do no clash name wise
    *
    * Make this general, so it checks all Entoties
    * within container, starting first with classes
    * then it should probably mark them, this will
    * be so we can then loop through all entities
    * including classes, of container c and for
    * every entity we come across in c we make
    * sure it doesn't have a name of something that 
    * is marked
    */
    private void checkClassNames(Container c)
    {
        /**
        * TODO: Always make sure this holds
        *
        * All objects that implement Container so far
        * are also Entities (hence they have a name)
        */
        Entity containerEntity = cast(Entity)c;
        assert(containerEntity);

        /* Get all types (Clazz so far) */
        Clazz[] classTypes;

        foreach (Statement statement; c.getStatements())
        {
            if (statement !is null && cast(Clazz) statement)
            {
                classTypes ~= cast(Clazz) statement;
            }
        }

        /* Declare each type */
        foreach (Clazz clazz; classTypes)
        {
            // gprintln("Name: "~resolver.generateName(modulle, clazz));
            /**
            * Check if the first class found with my name is the one being
            * processed, if so then it is fine, if not then error, it has
            * been used (that identifier) already
            *
            * TODO: We cann add a check here to not allow containerName == clazz
            * TODO: Call resolveUp as we can then stop class1.class1.class1
            * Okay top would resolve first part but class1.class2.class1
            * would not be caught by that
            *
            * TODO: This will meet inner clazz1 first, we need to do another check
            */
            if (resolver.resolveUp(c, clazz.getName()) != clazz)
            {
                Parser.expect("Cannot define class \"" ~ resolver.generateName(modulle,
                        clazz) ~ "\" as one with same name, \"" ~ resolver.generateName(modulle,
                        resolver.resolveUp(c, clazz.getName())) ~ "\" exists in container \"" ~ resolver.generateName(
                        modulle, containerEntity) ~ "\"");
            }
            else
            {
                /* Get the current container's parent container */
                Container parentContainer = containerEntity.parentOf();

                /* Don't allow a class to be named after it's container */
                // if(!parentContainer)
                // {
                if (cmp(containerEntity.getName(), clazz.getName()) == 0)
                {
                    Parser.expect("Class \"" ~ resolver.generateName(modulle,
                            clazz) ~ "\" cannot be defined within container with same name, \"" ~ resolver.generateName(
                            modulle, containerEntity) ~ "\"");
                }

                /* TODO: Loop througn Container ENtitys here */
                /* Make sure that when we call findPrecedence(entity) == current entity */

                // }

                /* TODO: We allow shaddowing so below is disabled */
                /* TODO: We should however use the below for dot-less resolution */
                // /* Find the name starting in upper cotainer */
                // Entity clazzAbove = resolveUp(parentContainer, clazz.getName());

                // if(!clazzAbove)
                // {

                // }
                // else
                // {
                //     Parser.expect("Name in use abpve us, bad"~to!(string)(clazz));
                // }

                /* If the Container's parent container is Module then we can have
                /* TODO: Check that it doesn;t equal any class up the chain */
                /* TODO: Exclude Module from this */

                // /* Still check if there is something with our name above us */
                // Container parentContainer = c.parentOf();

                // /* If at this level container we find duplicate */
                // if(resolveUp(parentContainer, clazz.getName()))
                // {

                //         Parser.expect("Class with name "~clazz.getName()~" defined in class "~c.getName());

                // }

            }
        }

        /**
        * TODO: Now we should loop through each class and do the same
        * so we have all types defined
        */
        //gprintln("Defined classes: "~to!(string)(Program.getAllOf(new Clazz(""), cast(Statement[])marked)));

        /**
        * By now we have confirmed that within the current container
        * there are no classes defined with the same name
        *
        * We now check each Class recursively, once we are done
        * we mark the class entity as "ready" (may be referenced)
        */
        foreach (Clazz clazz; classTypes)
        {
            gprintln("Check recursive " ~ to!(string)(clazz), DebugType.WARNING);

            /* Check the current class's types within */
            checkClassNames(clazz);

            // checkClassInherit(clazz);
        }

        /*Now we should loop through each class */
        /* Once outerly everything is defined we can then handle class inheritance names */
        /* We can also then handle refereces between classes */

        // gprintln("checkTypes: ")

    }

    /* Test name resolution */
    unittest
    {
        //assert()
    }

}

// /* Test name colliding with container name (1/3) [module] */
// unittest
// {
//     import std.file;
//     import std.stdio;
//     import compiler.lexer;
//     import compiler.parsing.core;

//     string sourceFile = "source/tlang/testing/collide_container_module1.t";

//     File sourceFileFile;
//     sourceFileFile.open(sourceFile); /* TODO: Error handling with ANY file I/O */
//     ulong fileSize = sourceFileFile.size();
//     byte[] fileBytes;
//     fileBytes.length = fileSize;
//     fileBytes = sourceFileFile.rawRead(fileBytes);
//     sourceFileFile.close();

//     string sourceCode = cast(string) fileBytes;
//     Lexer currentLexer = new Lexer(sourceCode);
//     currentLexer.performLex();

//     Parser parser = new Parser(currentLexer.getTokens());
//     Module modulle = parser.parse();
//     TypeChecker typeChecker = new TypeChecker(modulle);

//     /* Setup testing variables */
//     Entity container = typeChecker.getResolver().resolveBest(typeChecker.getModule, "y");
//     Entity colliderMember = typeChecker.getResolver().resolveBest(typeChecker.getModule, "y.y");

//     try
//     {
//         /* Perform test */
//         typeChecker.beginCheck();

//         /* Shouldn't reach here, collision exception MUST occur */
//         assert(false);
//     }
//     catch (CollidingNameException e)
//     {
//         /* Make sure the member y.y collided with root container (module) y */
//         assert(e.defined == container);
//     }
// }



// /* Test name colliding with container name (2/3) [module, nested collider] */
// unittest
// {
//     import std.file;
//     import std.stdio;
//     import compiler.lexer;
//     import compiler.parsing.core;

//     string sourceFile = "source/tlang/testing/collide_container_module2.t";

//     File sourceFileFile;
//     sourceFileFile.open(sourceFile); /* TODO: Error handling with ANY file I/O */
//     ulong fileSize = sourceFileFile.size();
//     byte[] fileBytes;
//     fileBytes.length = fileSize;
//     fileBytes = sourceFileFile.rawRead(fileBytes);
//     sourceFileFile.close();

//     string sourceCode = cast(string) fileBytes;
//     Lexer currentLexer = new Lexer(sourceCode);
//     currentLexer.performLex();

//     Parser parser = new Parser(currentLexer.getTokens());
//     Module modulle = parser.parse();
//     TypeChecker typeChecker = new TypeChecker(modulle);

//     /* Setup testing variables */
//     Entity container = typeChecker.getResolver().resolveBest(typeChecker.getModule, "y");
//     Entity colliderMember = typeChecker.getResolver().resolveBest(typeChecker.getModule, "y.a.b.c.y");

//     try
//     {
//         /* Perform test */
//         typeChecker.beginCheck();

//         /* Shouldn't reach here, collision exception MUST occur */
//         assert(false);
//     }
//     catch (CollidingNameException e)
//     {
//         /* Make sure the member y.a.b.c.y collided with root container (module) y */
//         assert(e.defined == container);
//     }
// }

// /* Test name colliding with container name (3/3) [container (non-module), nested collider] */
// unittest
// {
//     import std.file;
//     import std.stdio;
//     import compiler.lexer;
//     import compiler.parsing.core;

//     string sourceFile = "source/tlang/testing/collide_container_non_module.t";

//     File sourceFileFile;
//     sourceFileFile.open(sourceFile); /* TODO: Error handling with ANY file I/O */
//     ulong fileSize = sourceFileFile.size();
//     byte[] fileBytes;
//     fileBytes.length = fileSize;
//     fileBytes = sourceFileFile.rawRead(fileBytes);
//     sourceFileFile.close();

//     string sourceCode = cast(string) fileBytes;
//     Lexer currentLexer = new Lexer(sourceCode);
//     currentLexer.performLex();

//     Parser parser = new Parser(currentLexer.getTokens());
//     Module modulle = parser.parse();
//     TypeChecker typeChecker = new TypeChecker(modulle);

//     /* Setup testing variables */
//     Entity container = typeChecker.getResolver().resolveBest(typeChecker.getModule, "a.b.c");
//     Entity colliderMember = typeChecker.getResolver().resolveBest(typeChecker.getModule, "a.b.c.c");

//     try
//     {
//         /* Perform test */
//         typeChecker.beginCheck();

//         /* Shouldn't reach here, collision exception MUST occur */
//         assert(false);
//     }
//     catch (CollidingNameException e)
//     {
//         /* Make sure the member a.b.c.c collided with a.b.c container */
//         assert(e.defined == container);
//     }
// }

// /* Test name colliding with member */
// unittest
// {
//     import std.file;
//     import std.stdio;
//     import compiler.lexer;
//     import compiler.parsing.core;

//     string sourceFile = "source/tlang/testing/collide_member.t";

//     File sourceFileFile;
//     sourceFileFile.open(sourceFile); /* TODO: Error handling with ANY file I/O */
//     ulong fileSize = sourceFileFile.size();
//     byte[] fileBytes;
//     fileBytes.length = fileSize;
//     fileBytes = sourceFileFile.rawRead(fileBytes);
//     sourceFileFile.close();

//     string sourceCode = cast(string) fileBytes;
//     Lexer currentLexer = new Lexer(sourceCode);
//     currentLexer.performLex();

//     Parser parser = new Parser(currentLexer.getTokens());
//     Module modulle = parser.parse();
//     TypeChecker typeChecker = new TypeChecker(modulle);

//     /* Setup testing variables */
//     Entity memberFirst = typeChecker.getResolver().resolveBest(typeChecker.getModule, "a.b");

//     try
//     {
//         /* Perform test */
//         typeChecker.beginCheck();

//         /* Shouldn't reach here, collision exception MUST occur */
//         assert(false);
//     }
//     catch (CollidingNameException e)
//     {
//         /* Make sure the member a.b.c.c collided with a.b.c container */
//         assert(e.attempted != memberFirst);
//     }
// }

// /* Test name colliding with member (check that the member defined is class (precendence test)) */
// unittest
// {
//     import std.file;
//     import std.stdio;
//     import compiler.lexer;
//     import compiler.parsing.core;

//     string sourceFile = "source/tlang/testing/precedence_collision_test.t";

//     File sourceFileFile;
//     sourceFileFile.open(sourceFile); /* TODO: Error handling with ANY file I/O */
//     ulong fileSize = sourceFileFile.size();
//     byte[] fileBytes;
//     fileBytes.length = fileSize;
//     fileBytes = sourceFileFile.rawRead(fileBytes);
//     sourceFileFile.close();

//     string sourceCode = cast(string) fileBytes;
//     Lexer currentLexer = new Lexer(sourceCode);
//     currentLexer.performLex();

//     Parser parser = new Parser(currentLexer.getTokens());
//     Module modulle = parser.parse();
//     TypeChecker typeChecker = new TypeChecker(modulle);

//     /* Setup testing variables */
//     Entity ourClassA = typeChecker.getResolver().resolveBest(typeChecker.getModule, "a");

//     try
//     {
//         /* Perform test */
//         typeChecker.beginCheck();

//         /* Shouldn't reach here, collision exception MUST occur */
//         assert(false);
//     }
//     catch (CollidingNameException e)
//     {
//         /* Make sure the member attempted was Variable and defined was Clazz */
//         assert(cast(Variable)e.attempted);
//         assert(cast(Clazz)e.defined);
//     }
// }


// /* Test name colliding with container name (1/2) */
// unittest
// {
//     import std.file;
//     import std.stdio;
//     import compiler.lexer;
//     import compiler.parsing.core;

//     string sourceFile = "source/tlang/testing/collide_container.t";

//     File sourceFileFile;
//     sourceFileFile.open(sourceFile); /* TODO: Error handling with ANY file I/O */
//     ulong fileSize = sourceFileFile.size();
//     byte[] fileBytes;
//     fileBytes.length = fileSize;
//     fileBytes = sourceFileFile.rawRead(fileBytes);
//     sourceFileFile.close();

//     string sourceCode = cast(string) fileBytes;
//     Lexer currentLexer = new Lexer(sourceCode);
//     currentLexer.performLex();

//     Parser parser = new Parser(currentLexer.getTokens());
//     Module modulle = parser.parse();
//     TypeChecker typeChecker = new TypeChecker(modulle);

//     /* Setup testing variables */
//     Entity container = typeChecker.getResolver().resolveBest(typeChecker.getModule, "y");
//     Entity colliderMember = typeChecker.getResolver().resolveBest(typeChecker.getModule, "y.y");

//     try
//     {
//         /* Perform test */
//         typeChecker.beginCheck();

//         /* Shouldn't reach here, collision exception MUST occur */
//         assert(false);
//     }
//     catch (CollidingNameException e)
//     {
//         /* Make sure the member y.y collided with root container (module) y */
//         assert(e.defined == container);
//     }
// }


// unittest
// {
//     /* TODO: Add some unit tests */
//     import std.file;
//     import std.stdio;
//     import compiler.lexer;
//     import compiler.parsing.core;

//     // isUnitTest = true;

//     string sourceFile = "source/tlang/testing/basic1.t";

//     gprintln("Reading source file '" ~ sourceFile ~ "' ...");
//     File sourceFileFile;
//     sourceFileFile.open(sourceFile); /* TODO: Error handling with ANY file I/O */
//     ulong fileSize = sourceFileFile.size();
//     byte[] fileBytes;
//     fileBytes.length = fileSize;
//     fileBytes = sourceFileFile.rawRead(fileBytes);
//     sourceFileFile.close();

//     gprintln("Performing tokenization on '" ~ sourceFile ~ "' ...");

//     /* TODO: Open source file */
//     string sourceCode = cast(string) fileBytes;
//     // string sourceCode = "hello \"world\"|| ";
//     //string sourceCode = "hello \"world\"||"; /* TODO: Implement this one */
//     // string sourceCode = "hello;";
//     Lexer currentLexer = new Lexer(sourceCode);
//     currentLexer.performLex();
    

//     gprintln("Collected " ~ to!(string)(currentLexer.getTokens()));

//     gprintln("Parsing tokens...");
//     Parser parser = new Parser(currentLexer.getTokens());
//     Module modulle = parser.parse();

//     gprintln("Type checking and symbol resolution...");
//     try
//     {
//         TypeChecker typeChecker = new TypeChecker(modulle);

//     }
//     // catch(CollidingNameException e)
//     // {
//     //     gprintln(e.msg, DebugType.ERROR);
//     //     //gprintln("Stack trace:\n"~to!(string)(e.info));
//     // }
//     catch (TypeCheckerException e)
//     {
//         gprintln(e.msg, DebugType.ERROR);
//     }

//     /* Test first-level resolution */
//     // assert(cmp(typeChecker.isValidEntity(modulle.getStatements(), "clazz1").getName(), "clazz1")==0);

//     // /* Test n-level resolution */
//     // assert(cmp(typeChecker.isValidEntity(modulle.getStatements(), "clazz_2_1.clazz_2_2").getName(), "clazz_2_2")==0);
//     // assert(cmp(typeChecker.isValidEntity(modulle.getStatements(), "clazz_2_1.clazz_2_2.j").getName(), "j")==0);
//     // assert(cmp(typeChecker.isValidEntity(modulle.getStatements(), "clazz_2_1.clazz_2_2.clazz_2_2_1").getName(), "clazz_2_2_1")==0);
//     // assert(cmp(typeChecker.isValidEntity(modulle.getStatements(), "clazz_2_1.clazz_2_2").getName(), "clazz_2_2")==0);

//     // /* Test invalid access to j treating it as a Container (whilst it is a Variable) */
//     // assert(typeChecker.isValidEntity(modulle.getStatements(), "clazz_2_1.clazz_2_2.j.p") is null);

// }
