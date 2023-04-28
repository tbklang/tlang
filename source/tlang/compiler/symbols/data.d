module tlang.compiler.symbols.data;

public import tlang.compiler.symbols.check;
import std.conv : to;
import tlang.compiler.typecheck.dependency.core : Context;


/**
* TODO: Implement the blow and use them
*
* These are just to use for keeping track of what
* valid identifiers are.
*
* Actually it might be, yeah it will
*/

public class Program
{
    private string moduleName;
    private Program[] importedModules;

    private Statement[] statements;

    this(string moduleName)
    {
        this.moduleName = moduleName;
    }

    public void addStatement(Statement statement)
    {
        statements ~= statement;
    }

    public static StatementType[] getAllOf(StatementType)(StatementType, Statement[] statements)
    {
        StatementType[] statementsMatched;

        foreach(Statement statement; statements)
        {
            /* TODO: Remove null, this is for unimpemented */
            if(statement !is null && cast(StatementType)statement)
            {
                statementsMatched ~= cast(StatementType)statement;
            }
        }

        return statementsMatched;
    }

    public Variable[] getGlobals()
    {
        Variable[] variables;

        foreach(Statement statement; statements)
        {
            if(typeid(statement) == typeid(Variable))
            {
                variables ~= cast(Variable)statement;
            }
        }

        return variables;
    }

    /* TODO: Make this use weights */
    public Statement[] getStatements()
    {
        /* Re-ordered by lowest wieght first */
        Statement[] stmntsRed;

        bool wCmp(Statement lhs, Statement rhs)
        {
            return lhs.weight < rhs.weight;
        }
        import std.algorithm.sorting;
        stmntsRed = sort!(wCmp)(statements).release;
    

        return stmntsRed;
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
public class TypedEntity : Entity
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
}

public import tlang.compiler.symbols.containers;

public class ArgumentList
{

}


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
}

public class Variable : TypedEntity
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
}


public import tlang.compiler.symbols.expressions;





/**
* TODO: Rename to `VariableDeclarationAssignment`
*/
public class VariableAssignment : Statement
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

    public void setVariable(Variable variable)
    {
        this.variable = variable;
    }

    public override string toString()
    {
        return "[varAssignDec'd: To: "~variable.toString()~"]";
    }
}

/**
* TODO: Rename to ``
*/
public class VariableAssignmentStdAlone : Statement
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


public class IdentExpression : Expression
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
}

public class VariableExpression : IdentExpression
{

    this(string identifier)
    {
        super(identifier);
    }



    import tlang.compiler.typecheck.core;
    public override string evaluateType(TypeChecker typeChecker, Container c)
    {
        string type;


        return null;
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

public final class FunctionCall : Call
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

        /* Statement level weighting is 2 */
        weight = 2;
    }
    
    public Expression getReturnExpression()
    {
        return returnExpression;
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
}

public final class DiscardStatement : Statement
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