module tlang.compiler.symbols.data;

public import tlang.compiler.symbols.check;
import std.conv : to;
import tlang.compiler.typecheck.dependency.core : Context;

// For debug printing
import tlang.misc.logging;

// AST manipulation interfaces
import tlang.compiler.symbols.mcro : MStatementSearchable, MStatementReplaceable, MCloneable;

// Module entry management
import tlang.compiler.modman : ModuleEntry;

/** 
 * The _program_ holds a bunch of _modules_ as
 * its _body statements_ (hence being a `Container` type).
 * A program, unlike a module, is not an `Entity` - meaning
 * it has no name associated with it **but** it is the root
  * of the AST tree.
 */
public final class Program : Container
{
    /** 
     * Module entry to module mappings
     *
     * Used for visitation marking
     */
    private Module[string] modsMap;

    /** 
     * Modules this program is made up of
     */
    private Module[] modules;

    /** 
     * Constructs a new empty `Program`
     */
    this()
    {

    }

    /** 
     * Adds a new `Module` to this program
     *
     * Params:
     *   newModule = the new `Module` to add
     */
    public void addModule(Module newModule)
    {
        addStatement(newModule);
    }

    /** 
     * Returns the list of all modules which
     * make up this program
     *
     * Returns: the array of modules
     */
    public Module[] getModules()
    {
        // TODO: Should this not use the modmap.values()?
        return this.modules;
    }

    public Statement[] search(TypeInfo_Class clazzType)
    {
        // TODO: Implement me
        return [];
    }

    public bool replace(Statement thiz, Statement that)
    {
        // TODO: Implement me
        return false;
    }

    public void addStatement(Statement statement)
    {
        // Should only be adding modules to a program
        assert(cast(Module)statement);

        this.modules ~= cast(Module)statement;
    }

    public void addStatements(Statement[] statements)
    {
        foreach(Statement statement; statements)
        {
            addStatement(statement);
        }
    }

    public Statement[] getStatements()
    {
        return cast(Statement[])this.modules;
    }

    /** 
     * Check if the given module entry
     * is present. This is based on whether
     * a module entry within the internal
     * map is present which has a name equal
     * to the incoming entry
     *
     * Params:
     *   ent = the module entry to test
     * Returns: `true` if such an entry
     * is present, otherwise `false`
     */
    public bool isEntryPresent(ModuleEntry ent)
    {
        foreach(string key; this.modsMap.keys())
        {
            if(key == ent.getName())
            {
                return true;
            }
        }

        return false;
    }

    /** 
     * Marks the given entry as present.
     * This effectively means simply adding
     * the name of the incoming module entry
     * as a key to the internal map but
     * without it mapping to a module 
     * in particular
     *
     * Params:
     *   ent = the module entry to mark
     */
    public void markEntryAsVisited(ModuleEntry ent)
    {
        this.modsMap[ent.getName()] = null; // TODO: You should then call set when done
    }

    /** 
     * Given a module entry this will assign
     * (map) a module to it. Along with doing
     * this the incoming module shall be added
     * to the body of this `Program` and this
     * module will have its parent set to said
     * `Program`.
     *
     * Params:
     *   ent = the module entry
     *   mod = the module itself
     */
    public void setEntryModule(ModuleEntry ent, Module mod)
    {
        // TODO: Sanity check for already present?
        this.modsMap[ent.getName()] = mod;

        // Add module to body
        addModule(mod);

        // Parent the given Module to the Program
        mod.parentTo(this);
        // (TODO: Should this not be explctly done within the parser)
    }

    // TODO: Make this part of debug option
    public void debugDump()
    {
        DEBUG("Dumping modules imported into program:");
        import niknaks.debugging : dumpArray;
        import std.stdio : writeln;
        Module[] modulesImported = this.modules;
        writeln(dumpArray!(modulesImported));
    }

    /** 
     * Returns an informative string about the
     * program's details along with the modules
     * it is made up of
     *
     * Returns: a string
     */
    public override string toString()
    {
        return "Program [modules: "~to!(string)(this.modules)~"]";
    }
}

public class Statement
{

    public byte weight = 0;

    /* !!!! BEGIN TYPE CHECK ROUTINES AND DATA !!!! */
    /* TODO: Used for type checking */
    
    public Context context;
    public void setContext(Context context)
    {
        this.context = context;
    }

    public Context getContext()
    {
        return context;
    }
    /* !!!! END TYPE CHECK ROUTINES AND DATA !!!! */











    private static ulong rollingCount = 0;

    private Container container;
    

    public final void parentTo(Container container)
    {
        this.container = container;
    }

    public final Container parentOf()
    {
        return container;
    }

    public override string toString()
    {
        return to!(string)(rollingCount++);
    }
}

public enum AccessorType
{
    PUBLIC, PRIVATE, PROTECTED, UNKNOWN
}

public enum InitScope
{
    VIRTUAL, STATIC, UNKNOWN
}

public class Assignment : Statement
{
    private string identifier;
    private Expression assignmentExpression;

    this(string identifier, Expression assignmentExpression)
    {
        this.identifier = identifier;
        this.assignmentExpression = assignmentExpression;
    }
}

/** 
 * Entity
 *
 * Declared variables, defined classes and functions
 */
public class Entity : Statement
{
    /* Accessor type */
    private AccessorType accessorType = AccessorType.PUBLIC;

    /* Function/Modifier type */
    private InitScope initScope;

    /* Name of the entity (class's name, function's name, variable's name) */
    protected string name;

    /* If this entity is extern'd */
    private bool isExternalEntity;

    this(string name, bool isExternalEntity = false)
    {
        this.name = name;
        this.isExternalEntity = isExternalEntity;
    }

    public bool isExternal()
    {
        return isExternalEntity;
    }

    public void makeExternal()
    {
        isExternalEntity = true;
    }

    public void setAccessorType(AccessorType accessorType)
    {
        this.accessorType = accessorType;
    }

    public AccessorType getAccessorType()
    {
        return accessorType;
    }

    public void setModifierType(InitScope initScope)
    {
        this.initScope = initScope;
    }

    public InitScope getModifierType()
    {
        return initScope;
    }

    public string getName()
    {
        return name;
    }
}

/* TODO: DO we need intermediary class, TypedEntity */
import tlang.compiler.symbols.mcro : MTypeRewritable;
public class TypedEntity : Entity, MTypeRewritable
{
    private string type;

    /* TODO: Return type/variable type in here (do what we did for ENtity with `name/identifier`) */
    this(string name, string type)
    {
        super(name);
        this.type = type;
    }

    public string getType()
    {
        return type;
    }

    public void setType(string type)
    {
        this.type = type;
    }
}

public import tlang.compiler.symbols.containers;

/** 
 * VariableParameter
 *
 * Represents a kindof-Variable which is used to indicate
 * it is a function's parameter - to differentiate between
 * those and other variables like local/global definitions
 * and so on
 *
 * These are only to be used in the `Function` class (below)
 */
public final class VariableParameter : Variable
{
    this(string type, string identifier)
    {
        super(type, identifier);
    }
}

/* TODO: Don't make this a Container, or maybe (make sure I don't rely on COntainer casting for other shit
* though, also the recent changes) */
public class Function : TypedEntity, Container
{
    private VariableParameter[] params;
    private Statement[] bodyStatements;

    this(string name, string returnType, Statement[] bodyStatements, VariableParameter[] params)
    {
        super(name, returnType);

        // Add the parameters first THEN the function's body statements
        // because they must be available before other statements
        // which may reference them, Secondly they must be added (the VariableParameter(s))
        // such that they are lookup-able.
        addStatements(cast(Statement[])params);

        // Add the funciton's body
        addStatements(bodyStatements);

        // Save a seperate copy of the parameters (to seperate them from the
        // other body stetements)
        this.params = params;

        /* Weighted as 1 */
        weight = 1;
    }

    public VariableParameter[] getParams()
    {
        return params;
    }

    public bool hasParams()
    {
        return params.length != 0;
    }

    public void addStatement(Statement statement)
    {
        this.bodyStatements~=statement;
    }

    public void addStatements(Statement[] statements)
    {
        this.bodyStatements~=statements;
    }

    public Statement[] getStatements()
    {
        import tlang.compiler.symbols.containers : weightReorder;
        return weightReorder(bodyStatements);
    }

    /**
    * This will sift through all the `Statement[]`'s in held
    * within this Function and will find those which are Variable
    */
    public Variable[] getVariables()
    {
        Variable[] variables;

        foreach(Statement statement; bodyStatements)
        {

            if(statement !is null && cast(Variable)statement)
            {
                variables ~= cast(Variable)statement;
            }
        }

        return variables;
    }

    public override string toString()
    {
        string argTypes;

        for(ulong i = 0; i < params.length; i++)
        {
            Variable variable = params[i];

            if(i == params.length-1)
            {
                argTypes ~= variable.getType();
            }
            else
            {
                argTypes ~= variable.getType() ~ ", ";
            }
        }
        
        return "Function (Name: "~name~", ReturnType: "~type~", Args: "~argTypes~")";
    }
    
    public override Statement[] search(TypeInfo_Class clazzType)
    {
        /* List of returned matches */
        Statement[] matches;

        /* Are we (ourselves) of this type? */
        if(clazzType.isBaseOf(this.classinfo))
        {
            matches ~= [this];
        }

        /* Recurse on each `Statement` making up our body */
        // NOTE: Using weight-reordered? Is that fine?
        foreach(Statement curStmt; getStatements())
        {
            MStatementSearchable curStmtCasted = cast(MStatementSearchable)curStmt;
            if(curStmtCasted)
            {
                matches ~= curStmtCasted.search(clazzType);
            }
        }

        return matches;
    }

    public override bool replace(Statement thiz, Statement that)
    {
        /* If we (`this`) are `thiz`, then we cannot replace */
        if(this == thiz)
        {
            return false;
        }
        /* If not ourself, then check the body statements */
        else
        {
            /**
             * First check each `Statement` that make sup our
             * body and see if we can replace that, else see
             * if we can recurse on each of the body statements
             * and apply replacement therein
             */
            // NOTE: Using weight-reordered? Is that fine?
            Statement[] bodyStmts = getStatements();
            for(ulong idx = 0; idx < bodyStmts.length; idx++)
            {
                Statement curBodyStmt = bodyStmts[idx];

                /* Should we directly replace the Statement in the body? */
                if(curBodyStmt == thiz)
                {
                    // Replace the statement in the body
                    // NOTE: The respective Variable Param must be swapped out too if need be
                    // (varParams[] subsetOf Statements[])
                    for(ulong varParamIdx = 0; varParamIdx < params.length; varParamIdx++)
                    {
                        VariableParameter curVarParam = params[varParamIdx];
                        if(curVarParam == thiz)
                        {
                            params[varParamIdx] = cast(VariableParameter)that;
                            break;
                        }
                    }
                    bodyStatements[idx] = that;

                    // Re-parent `that` to us
                    that.parentTo(this);

                    return true;
                }
                /* If we cannot, then recurse (try) on it */
                else if(cast(MStatementReplaceable)curBodyStmt)
                {
                    MStatementReplaceable curBodyStmtRepl = cast(MStatementReplaceable)curBodyStmt;
                    if(curBodyStmtRepl.replace(thiz, that))
                    {
                        return true;
                    }
                }
            }

            return false;
        }
    }
}

public class Variable : TypedEntity, MStatementSearchable, MStatementReplaceable, MCloneable
{
    /* TODO: Just make this an Expression */
    private VariableAssignment assignment;

    this(string type, string identifier)
    {
        super(identifier, type);


        /* Weighted as 2 */
        weight = 2;
    }

    public void addAssignment(VariableAssignment assignment)
    {
        this.assignment = assignment;
    }

    public VariableAssignment getAssignment()
    {
        return assignment;
    }

    public override string toString()
    {
        return "Variable (Ident: "~name~", Type: "~type~")";
    }

    public override Statement[] search(TypeInfo_Class clazzType)
    {
        /* List of returned matches */
        Statement[] matches;

        /* Are we (ourselves) of this type? */
        if(clazzType.isBaseOf(this.classinfo))
        {
            matches ~= [this];
        }

        /**
         * Recurse on the `VariableAssignment`
         */
        MStatementSearchable innerStmt = cast(MStatementSearchable)assignment;
        if(innerStmt)
        {
            matches ~= innerStmt.search(clazzType); 
        }

        return matches;
    }

    public override bool replace(Statement thiz, Statement that)
    {
        /* If we, the `Variable`, are the `thiz` then we cannot perform replacement */
        if(this == thiz)
        {
            return false;
        }
        /* Check if we should replace the `VariableAssignment` */
        else if(thiz == assignment)
        {
            assignment = cast(VariableAssignment)that;
            return true;
        }
        /* Recurse on the variable assignment (if there is one) */
        else if(assignment !is null)
        {
            return assignment.replace(thiz, that);
        }
        /* Exhausted all possibilities */
        else
        {
            return false;
        }
    }

    /** 
     * Clones this variable declaration recursively
     * including its assigned value (`VariableAssignment`)
     * if any.
     *
     * Param:
     *   newParent = the `Container` to re-parent the
     *   cloned `Statement`'s self to
     *
     * Returns: the cloned `Statement`
     */
    public override Statement clone(Container newParent = null)
    {
        Variable clonedVarDec;

        // If there's an assignment, then clone it
        VariableAssignment clonedVarAss = null;
        if(this.assignment)
        {
            // Clone the assignment
            clonedVarAss = cast(VariableAssignment)this.assignment.clone(); // TODO: If needs be we must re-parent manually
        }
        

        // Create new variable with same name and identifier
        clonedVarDec = new Variable(this.type, this.name);

        // Copy all properties across (TODO: Make sure we didn't miss any)
        clonedVarDec.accessorType = this.accessorType;
        clonedVarDec.isExternalEntity = this.isExternalEntity;
        clonedVarDec.assignment = clonedVarAss;
        clonedVarDec.container = this.container;

        // Parent outselves to the given parent
        clonedVarDec.parentTo(newParent);

        return clonedVarDec;
    }
}


public import tlang.compiler.symbols.expressions;





/**
* TODO: Rename to `VariableDeclarationAssignment`
*/
public class VariableAssignment : Statement, MStatementSearchable, MStatementReplaceable, MCloneable
{
    private Expression expression;
    private Variable variable;

    this(Expression expression)
    {
        this.expression = expression;
    }

    public Expression getExpression()
    {
        return expression;
    }

    public Variable getVariable()
    {
        return variable;
    }

    // NOTE-to-self: Very interesting method we have here, is this just for debugging?
    // (15th May 2023, whilst working on Meta)
    public void setVariable(Variable variable)
    {
        this.variable = variable;
    }

    public override string toString()
    {
        return "[varAssignDec'd: To: "~variable.toString()~"]";
    }

    public override Statement[] search(TypeInfo_Class clazzType)
    {
        /* List of returned matches */
        Statement[] matches;

        /* Are we (ourselves) of this type? */
        if(clazzType.isBaseOf(this.classinfo))
        {
            matches ~= [this];
        }

        /* Recurse on our `Expression` (if possible) */
        MStatementSearchable innerStmt = cast(MStatementSearchable)expression;
        if(innerStmt)
        {
            matches ~= innerStmt.search(clazzType); 
        }

        return matches;
    }

    public override bool replace(Statement thiz, Statement that)
    {
        /* We cannot replace ourselves directly */
        if(this == thiz)
        {
            return false;
        }
        /* Is the `Expression` the `thiz`, then swap out the expression */
        else if(expression == thiz)
        {
            // TODO: Any reparenting needed?
            expression = cast(Expression)that;
            return true;
        }
        /* Recurse on the `Expression` being assigned (if possible) */
        else if(cast(MStatementReplaceable)expression)
        {
            MStatementReplaceable replStmt = cast(MStatementReplaceable)expression;
            return replStmt.replace(thiz, that);
        }
        /* If not matched */
        else
        {
            return false;
        }
    }

    /** 
     * Clones this variable assignment by recursively cloning
     * the fields within (TODO: finish description)
     *
     * Param:
     *   newParent = the `Container` to re-parent the
     *   cloned `Statement`'s self to
     *
     * Returns: the cloned `Statement`
     */
    public override Statement clone(Container newParent = null)
    {
        // FIXME: Investigate if `Variable`? Must be cloned
        // ... would cuase infinite recursion and it isn't
        // ... reaslly a part of the AST (just a helper)
        // ... hence I do not believe it needs to be cloned
        // (If for some reason the association eneds to be)
        // ... updted then `Variable`'s `clone()' can call
        /// ... `setvariable(clonedVarDec)` (with itself)

        // Clone the expression (if supported, TODO: throw an error if not)
        Expression clonedExpression = null;
        if(cast(MCloneable)this.expression)
        {
            MCloneable cloneableExpression = cast(MCloneable)this.expression;
            clonedExpression = cast(Expression)cloneableExpression.clone(); // NOTE: Manually re-parent if
        }
        
        VariableAssignment clonedVarAss = new VariableAssignment(clonedExpression);

        // Parent outselves to the given parent
        clonedVarAss.parentTo(newParent);

        return clonedVarAss;
    }
}

/**
* TODO: Rename to ``
*/
public class VariableAssignmentStdAlone : Statement, MStatementSearchable, MStatementReplaceable
{
    private Expression expression;
    private string varName;

    this(string varName, Expression expression)
    {
        this.varName = varName;
        this.expression = expression;

        /* Weighted as 2 */
        weight = 2;
    }

    public Expression getExpression()
    {
        return expression;
    }

    public string getVariableName()
    {
        return varName;
    }

    public override string toString()
    {
        return "[varAssignStdAlone: To: "~varName~"]";
    }

    public override Statement[] search(TypeInfo_Class clazzType)
    {
        /* List of returned matches */
        Statement[] matches;

        /* Are we (ourselves) of this type? */
        if(clazzType.isBaseOf(this.classinfo))
        {
            matches ~= [this];
        }

        /**
         * Recurse on the assigned `Expression`
         */
        MStatementSearchable assignedStmtCasted = cast(MStatementSearchable)expression;
        if(assignedStmtCasted)
        {
            matches ~= assignedStmtCasted.search(clazzType); 
        }

        return matches;
    }

    public override bool replace(Statement thiz, Statement that)
    {
        /* If we, the `VariableAssignmentStdAlone`, are the `thiz` then we cannot perform replacement */
        if(this == thiz)
        {
            return false;
        }
        /* Check if we should replace the `Expression` being assigned? */
        else if(thiz == expression)
        {
            expression = cast(Expression)that;
            return true;
        }
        /* Recurse on the assigned `Expression` (if possible) */
        else if(cast(MStatementReplaceable)expression)
        {
            MStatementReplaceable expressionCasted = cast(MStatementReplaceable)expression;
            return expressionCasted.replace(thiz, that);
        }
        /* None */
        else
        {
            return false;
        }
    }
}

// TODO: Add an ArrayAssignment thing here, would be similiar to PointerDeference
// mmmh, we would also need to ensure during typechecking/codegen/emit that we don't
// do pointer arithmetic. Makes sense we would have a ArrayAssign and expression for indexers
// but during codegen we check WHO was being assigned to and their type and based on that
// generate the correct INSTRUCTION
public final class ArrayAssignment : Statement
{
    private Expression assignmentExpression;

    /** 
     * The left hand side of:
     *      e.g. myArray[i][1] = 2;
     *
     * Therefore the `myArray[i][1]` part
     */
    private ArrayIndex leftHandExpression;

    this(ArrayIndex leftHandExpression, Expression assignmentExpression)
    {
        this.leftHandExpression = leftHandExpression;
        this.assignmentExpression = assignmentExpression;

        /* Weighted as 2 */
        weight = 2;
    }

    public ArrayIndex getArrayLeft()
    {
        return leftHandExpression;
    }

    public Expression getAssignmentExpression()
    {
        return assignmentExpression;
    }

    public override string toString()
    {
        return "ArrayAssignment [leftHand: "~leftHandExpression.toString()~", assignmentExpr: "~assignmentExpression.toString()~"]";
    }
}


public class PointerDereferenceAssignment : Statement
{
    private Expression assignmentExpression;
    private Expression pointerExpression;
    private ulong derefCount;

    this(Expression pointerExpression, Expression assignmentExpression, ulong derefCount = 1)
    {
        this.pointerExpression = pointerExpression;
        this.assignmentExpression = assignmentExpression;
        this.derefCount = derefCount;

        /* Weighted as 2 */
        weight = 2;
    }

    public Expression getExpression()
    {
        return assignmentExpression;
    }

    public Expression getPointerExpression()
    {
        return pointerExpression;
    }

    public ulong getDerefCount()
    {
        return derefCount;
    }

    public override string toString()
    {
        return "[pointerDeref: From: "~pointerExpression.toString()~"]";
    }
}

public class IdentExpression : Expression, MStatementSearchable, MStatementReplaceable
{
    /* name */
    private string name;

    this(string name)
    {
        this.name = name;
    }

    public string getName()
    {
        return name;
    }

    public void updateName(string newName)
    {
        name = newName;
    }


    public override Statement[] search(TypeInfo_Class clazzType)
    {
        /* List of returned matches */
        Statement[] matches;

        /* Are we (ourselves) of this type? */
        if(clazzType.isBaseOf(this.classinfo))
        {
            matches ~= [this];
        }

        return matches;
    }

    public override bool replace(Statement thiz, Statement that)
    {
        // Nothing to replace within us
        return false;
    }
}

public class VariableExpression : IdentExpression
{

    this(string identifier)
    {
        super(identifier);
    }
    
    public override string toString()
    {
        return "[varExp: "~getName()~"]";
    }
}

public class Call : IdentExpression
{
    this(string ident)
    {
        super(ident);
    }
}

// FIXME: Finish adding proper `MStatementSearchable` and `MStatementReplaceable` to `FunctionCall`
public final class FunctionCall : Call, MStatementSearchable, MStatementReplaceable
{
    /* Whether this is statement-level function call or not */

    /** 
     * Function calls either appear as part of an expression
     * (i.e. from `parseExpression()`) or directly as a statement
     * in the body of a `Container`. This affects how code generation
     * works and hence one needs to disambiguate between the two.
     */
    private bool isStatementLevel = false;

    /* Argument list */
    private Expression[] arguments;

    this(string functionName, Expression[] arguments)
    {
        super(functionName);
        this.arguments = arguments;

        /* Weighted as 2 */
        weight = 2;
    }

    public override string toString()
    {
        return super.toString()~" "~name~"()";
    }

    public Expression[] getCallArguments()
    {
        return arguments;
    }

    /** 
     * Mark this function call as statement-level
     */
    public void makeStatementLevel()
    {
        this.isStatementLevel = true;
    }

    /** 
     * Determines if this function call is statement-level
     *
     * Returns: true if so, false otherwise
     */
    public bool isStatementLevelFuncCall()
    {
        return isStatementLevel;
    }

    public override Statement[] search(TypeInfo_Class clazzType)
    {
        // TODO: Implement me

        /* List of returned matches */
        Statement[] matches;

        /* Are we (ourselves) of this type? */
        if(clazzType.isBaseOf(this.classinfo))
        {
            matches ~= [this];
        }

        /**
         * Recurse on each `Expression` (if possible)
         */
        foreach(Expression callExp; arguments)
        {
            MStatementSearchable innerStmt = cast(MStatementSearchable)callExp;
            if(innerStmt)
            {
                matches ~= innerStmt.search(clazzType); 
            }
        }

        return matches;
    }

    public override bool replace(Statement thiz, Statement that)
    {
        // TODO: Implement me

        // /* Check if our `Expression` matches, then replace */
        // if(expression == thiz)
        // {
        //     // NOTE: This legit makes no sense and won't do anything, we could remove this
        //     // and honestly should probably make this return false
        //     // FIXME: Make this return `false` (see above)
        //     expression = cast(Expression)that;
        //     return true;
        // }
        // /* If not direct match, then recurse and replace (if possible) */
        // else if(cast(MStatementReplaceable)expression)
        // {
        //     MStatementReplaceable replStmt = cast(MStatementReplaceable)expression;
        //     return replStmt.replace(thiz, that);
        // }
        // /* If not direct match and not replaceable */
        // else
        // {
        //     return false;
        // }
        return true;
    }
}

/** 
 * ReturnStmt
 *
 * Represents a return statement with an expression
 * to be returned
 */
public final class ReturnStmt : Statement
{
    // The Expression being returned
    private Expression returnExpression;

    this(Expression returnExpression)
    {
        this.returnExpression = returnExpression;

        this();
    }

    this()
    {
        /* Statement level weighting is 2 */
        weight = 2;
    }
    
    public Expression getReturnExpression()
    {
        return returnExpression;
    }

    public bool hasReturnExpression()
    {
        return returnExpression !is null;
    }
}

/** 
 * IfStatement
 *
 * Represents an if statement with branches of code
 * and conditions per each
 */
public final class IfStatement : Entity, Container
{
    private Branch[] branches;

    private static ulong ifStmtContainerRollingNameCounter = 0;

    this(Branch[] branches)
    {
        ifStmtContainerRollingNameCounter++;
        super("ifStmt_"~to!(string)(ifStmtContainerRollingNameCounter));

        this.branches = branches;

        weight = 2;
    }

    public Branch[] getBranches()
    {
        return branches;
    }

    public override void addStatement(Statement statement)
    {
        branches ~= cast(Branch)statement;
    }

    public override void addStatements(Statement[] statements)
    {
        branches ~= cast(Branch[])statements;
    }

    public override Statement[] getStatements()
    {
        return cast(Statement[])branches;
    }

    public override string toString()
    {
        return "IfStmt";
    }

    public override Statement[] search(TypeInfo_Class clazzType)
    {
        /* List of returned matches */
        Statement[] matches;

        /* Are we (ourselves) of this type? */
        if(clazzType.isBaseOf(this.classinfo))
        {
            matches ~= [this];
        }

        /* Loop through each `Branch` and recurse on them */
        foreach(Branch curBranch; branches)
        {
            matches ~= curBranch.search(clazzType);
        }

        return matches;
    }

    public override bool replace(Statement thiz, Statement that)
    {
        /* If we (`this`) are `thiz`, then we cannot replace */
        if(this == thiz)
        {
            return false;
        }
        /* If not ourself, then check each `Branch` or recurse on them */
        else
        {
            /**
             * First check each `Branch` that makes up our
             * branches array and see if we can replace that,
             * else see if we can recurse on each of the branche
             * and apply replacement therein
             */
            Statement[] bodyStmts = getStatements();
            for(ulong idx = 0; idx < bodyStmts.length; idx++)
            {
                Statement curBodyStmt = bodyStmts[idx];

                /* Should we directly replace the Statement in the body? */
                if(curBodyStmt == thiz)
                {
                    // Replace the statement in the body
                    // FIXME: Apply parenting? Yes we should
                    branches[idx] = cast(Branch)that;
                    return true;
                }
                /* If we cannot, then recurse (try) on it */
                else if(cast(MStatementReplaceable)curBodyStmt)
                {
                    MStatementReplaceable curBodyStmtRepl = cast(MStatementReplaceable)curBodyStmt;
                    if(curBodyStmtRepl.replace(thiz, that))
                    {
                        return true;
                    }
                }
            }

            return false;
        }
    }
}

/** 
 * WhileLoop
 *
 * Represents a while loop with conditional code
 */
public final class WhileLoop : Entity, Container
{
    private Branch branch;
    private static ulong whileStmtContainerRollingNameCounter = 0;
    public const bool isDoWhile;

    /** 
     * Creates a new While Loop parser node, optionally specifying
     * if this is to be interpreted (in-post) as a while-loop
     * or do-while loop
     *
     * Params:
     *   branch = The <code>Branch</code> that makes up this while
     *            loop
     *   isDoWhile = If <code>true</code> then interpret this as a 
     *               do-while loop, however if <code>false</code>
     *               then a while-loop (default optional value)
     */
    this(Branch branch, bool isDoWhile = false)
    {
        whileStmtContainerRollingNameCounter++;
        super("whileStmt_"~to!(string)(whileStmtContainerRollingNameCounter));

        this.branch = branch;
        this.isDoWhile = isDoWhile;

        weight = 2;
    }

    public Branch getBranch()
    {
        return branch;
    }

    public override void addStatement(Statement statement)
    {
        // You should only be adding one branch to a while loop
        assert(branch is null);
        branch = cast(Branch)statement;
    }

    public override void addStatements(Statement[] statements)
    {
        // Only one Branch in the given input list
        assert(statements.length == 1);
        
        // You should only be adding one branch to a while loop
        assert(branch is null);

        branch = (cast(Branch[])statements)[0];
    }

    public override Statement[] getStatements()
    {
        return cast(Statement[])[branch];
    }

    public override string toString()
    {
        return "WhileLoop";
    }

    public override Statement[] search(TypeInfo_Class clazzType)
    {
        /* List of returned matches */
        Statement[] matches;

        /* Are we (ourselves) of this type? */
        if(clazzType.isBaseOf(this.classinfo))
        {
            matches ~= [this];
        }

        /* Recurse on the the `Branch` */
        if(cast(MStatementSearchable)branch)
        {
            MStatementSearchable branchCasted = cast(MStatementSearchable)branch;
            if(branchCasted)
            {
                matches ~= branchCasted.search(clazzType);
            }
        }

        return matches;
    }

    public override bool replace(Statement thiz, Statement that)
    {
        /* If we (`this`) are `thiz`, then we cannot replace */
        if(this == thiz)
        {
            return false;
        }
        /* If the `Branch` is to be replaced */
        else if(branch == thiz)
        {
            branch = cast(Branch)that;
            return true;
        }
        /* If not ourself, then recurse on the `Branch` */
        else
        {
            return branch.replace(thiz, that);
        }
    }
}

public final class ForLoop : Entity, Container
{
    private Statement preLoopStatement;
    private Branch branch;    
    private bool hasPostIterate;
    private static ulong forStmtContainerRollingNameCounter = 0;

    /** 
     * Creates a new For Loop parser node
     *
     * Params:
     *   
     *   preLoopStatement = The <code>Statement</code> to run before
     *            beginning the first iteration
     *   branch = The <code>Branch</code> that makes up this for
     *            loop
     */
    this(Branch branch, Statement preLoopStatement = null, bool hasPostIterate = false)
    {
        forStmtContainerRollingNameCounter++;
        super("forStmt_"~to!(string)(forStmtContainerRollingNameCounter));

        this.preLoopStatement = preLoopStatement;
        this.branch = branch;
        this.hasPostIterate = hasPostIterate;

        weight = 2;
    }

    public bool hasPostIterateStatement()
    {
        return hasPostIterate;
    }

    public bool hasPreRunStatement()
    {
        return !(preLoopStatement is null);
    }

    public Branch getBranch()
    {
        return branch;
    }

    public Statement getPreRunStatement()
    {
        return preLoopStatement;
    }

    public override void addStatement(Statement statement)
    {
        // You should only be adding one branch to a for loop
        assert(branch is null);
        branch = cast(Branch)statement;
    }

    public override void addStatements(Statement[] statements)
    {
        // Only one Branch in the given input list
        assert(statements.length == 1);
        
        // You should only be adding one branch to a for loop
        assert(branch is null);

        branch = (cast(Branch[])statements)[0];
    }

    public override Statement[] getStatements()
    {
        // If there is a pre-run statement then prepend it
        if(hasPreRunStatement())
        {
            return cast(Statement[])[preLoopStatement, branch];
        }
        // If not, then just the Branch container
        else
        {
            return cast(Statement[])[branch];
        }
    }

    public override string toString()
    {
        return "ForLoop";
    }

    public override Statement[] search(TypeInfo_Class clazzType)
    {
        /* List of returned matches */
        Statement[] matches;

        /* Are we (ourselves) of this type? */
        if(clazzType.isBaseOf(this.classinfo))
        {
            matches ~= [this];
        }

        /* Recurse on the pre-loop `Statement` */
        if(cast(MStatementSearchable)preLoopStatement)
        {
            MStatementSearchable preLoopStatementCasted = cast(MStatementSearchable)preLoopStatement;
            if(preLoopStatementCasted)
            {
                matches ~= preLoopStatementCasted.search(clazzType);
            }
        }

        /* Recurse on the the `Branch` */
        if(cast(MStatementSearchable)branch)
        {
            MStatementSearchable branchCasted = cast(MStatementSearchable)branch;
            if(branchCasted)
            {
                matches ~= branchCasted.search(clazzType);
            }
        }

        return matches;
    }

    public override bool replace(Statement thiz, Statement that)
    {
        /* If we (`this`) are `thiz`, then we cannot replace */
        if(this == thiz)
        {
            return false;
        }
        /* If the `Branch` is to be replaced */
        else if(branch == thiz)
        {
            branch = cast(Branch)that;
            return true;
        }
        /* If the pre-loop `Statement` is to be replaced */
        else if(preLoopStatement == thiz)
        {
            preLoopStatement = cast(Statement)that;
            return true;
        }
        /* If not ourself, then recurse on the `Branch` */
        else
        {
            return branch.replace(thiz, that);
        }
    }
}

/** 
 * Branch
 *
 * Represents a condition and code attached to
 * run on said condition
 *
 * NOTE: I feel as though this should be a container
 * with a `generalPass` applied to it in `dependency/core.d`
 */
public final class Branch : Entity, Container
{
    private Expression branchCondition;
    private Statement[] branchBody;

    private static ulong branchContainerRollingNameCounter = 0;

    /** 
     * Creates a new Branch which will couple a condition
     * as an instance of <code>Expression</code> and a body
     * of <code>Statement</code>(s) apart of it
     *
     * Params:
     *   condition = The condition as an <code>Expression</code> 
     *   branch = The body of <code>Statement</code>(s) making up the branch
     */
    this(Expression condition, Statement[] branch)
    {
        branchContainerRollingNameCounter++;
        super("branch_"~to!(string)(branchContainerRollingNameCounter));

        this.branchCondition = condition;
        this.branchBody = branch;
    }

    /** 
     * Effectively checks if this branch is an 'else' branch
     *
     * Returns: <code>true</code> if so, <code>false</code>
     * otherwise
     */
    public bool hasCondition()
    {
        return !(branchCondition is null);
    }

    /** 
     * Returns the condition of the branch
     *
     * Returns: The condition as an instance of <code>Expression</code>
     */
    public Expression getCondition()
    {
        return branchCondition;
    }


    public Statement[] getBody()
    {
        return branchBody;
    }

    public override void addStatement(Statement statement)
    {
        branchBody ~= statement;
    }

    public override void addStatements(Statement[] statements)
    {
        branchBody ~= statements;
    }

    public override Statement[] getStatements()
    {
        return branchBody;
    }

    public override string toString()
    {
        return "Branch";
    }

    public override Statement[] search(TypeInfo_Class clazzType)
    {
        /* List of returned matches */
        Statement[] matches;

        /* Are we (ourselves) of this type? */
        if(clazzType.isBaseOf(this.classinfo))
        {
            matches ~= [this];
        }

        /* Recurse on the branch condition `Expression` */
        if(cast(MStatementSearchable)branchCondition)
        {
            MStatementSearchable branchConditionCasted = cast(MStatementSearchable)branchCondition;
            if(branchConditionCasted)
            {
                matches ~= branchConditionCasted.search(clazzType);
            }
        }

        /* Recurse on each `Statement` making up our body */
        // NOTE: Using weight-reordered? Is that fine?
        foreach(Statement curStmt; getStatements())
        {
            MStatementSearchable curStmtCasted = cast(MStatementSearchable)curStmt;
            if(curStmtCasted)
            {
                matches ~= curStmtCasted.search(clazzType);
            }
        }

        return matches;
    }

    public override bool replace(Statement thiz, Statement that)
    {
        /* If we (`this`) are `thiz`, then we cannot replace */
        if(this == thiz)
        {
            return false;
        }
        /* If the branch condition `Expression` is matching */
        else if(branchCondition == thiz)
        {
            branchCondition = cast(Expression)that;
            return true;
        }
        /* If not ourself, then check the body statements */
        else
        {
            /**
             * First check each `Statement` that make sup our
             * body and see if we can replace that, else see
             * if we can recurse on each of the body statements
             * and apply replacement therein
             */
            // NOTE: Using weight-reordered? Is that fine?
            Statement[] bodyStmts = getStatements();
            for(ulong idx = 0; idx < bodyStmts.length; idx++)
            {
                Statement curBodyStmt = bodyStmts[idx];

                /* Should we directly replace the Statement in the body? */
                if(curBodyStmt == thiz)
                {
                    // Replace the statement in the body
                    // FIXME: Apply parenting? Yes we should
                    branchBody[idx] = that;
                    return true;
                }
                /* If we cannot, then recurse (try) on it */
                else if(cast(MStatementReplaceable)curBodyStmt)
                {
                    MStatementReplaceable curBodyStmtRepl = cast(MStatementReplaceable)curBodyStmt;
                    if(curBodyStmtRepl.replace(thiz, that))
                    {
                        return true;
                    }
                }
            }

            return false;
        }
    }
}

public final class DiscardStatement : Statement, MStatementSearchable, MStatementReplaceable
{
    private Expression expression;

    this(Expression expression)
    {
        this.expression = expression;

        /* Weighted as 2 */
        weight = 2;
    }

    public Expression getExpression()
    {
        return expression;
    }

    public override string toString()
    {
        return "[DiscardStatement: (Exp: "~expression.toString()~")]";
    }

    public override Statement[] search(TypeInfo_Class clazzType)
    {
        /* List of returned matches */
        Statement[] matches;

        /* Are we (ourselves) of this type? */
        if(clazzType.isBaseOf(this.classinfo))
        {
            matches ~= [this];
        }

        /* Recurse on our `Expression` (if possible) */
        MStatementSearchable innerStmt = cast(MStatementSearchable)expression;
        if(innerStmt)
        {
            matches ~= innerStmt.search(clazzType); 
        }

        return matches;
    }

    public override bool replace(Statement thiz, Statement that)
    {
        import std.stdio;
        writeln("Replace() enter discard");

        /* Check if our `Expression` matches, then replace */
        if(expression == thiz)
        {
            // NOTE: This legit makes no sense and won't do anything, we could remove this
            // and honestly should probably make this return false
            // FIXME: Make this return `false` (see above)
            expression = cast(Expression)that;
            return true;
        }
        /* If not direct match, then recurse and replace (if possible) */
        else if(cast(MStatementReplaceable)expression)
        {
            MStatementReplaceable replStmt = cast(MStatementReplaceable)expression;
            return replStmt.replace(thiz, that);
        }
        /* If not direct match and not replaceable */
        else
        {
            return false;
        }
    }
}

public final class ExternStmt : Statement
{
    // Pseudo entity created
    private Entity pseudoEntity;

    private SymbolType externType;

    this(Entity pseudoEntity, SymbolType externType)
    {
        // External symbols are either external functions or external variables
        assert(externType == SymbolType.EXTERN_EFUNC || externType == SymbolType.EXTERN_EVAR);

        this.pseudoEntity = pseudoEntity;
        this.externType = externType;
    }

    public string getExternalName()
    {
        return pseudoEntity.getName();
    }

    public SymbolType getExternType()
    {
        return externType;
    }

    public Entity getPseudoEntity()
    {
        return pseudoEntity;
    }

    public override string toString()
    {
        return "[ExternStatement: (Symbol name: "~getExternalName()~")]";
    }
}