module tlang.compiler.symbols.containers;

import tlang.compiler.symbols.data;
import std.conv : to;
import tlang.compiler.symbols.typing.core;

// AST manipulation interfaces
import tlang.compiler.symbols.mcro : MStatementSearchable, MStatementReplaceable, MCloneable;

/**
* Used so often that we may as well
* declare it once
*
* TODO: Check if we could do it with interfaces?
*/
public Statement[] weightReorder(Statement[] statements)
{
    import std.algorithm.sorting : sort;
    import std.algorithm.mutation : SwapStrategy;

    /* Re-ordered by lowest wieght first */
    Statement[] stmntsRed;

    /* Comparator for Statement objects */
    bool wCmp(Statement lhs, Statement rhs)
    {
        return lhs.weight < rhs.weight;
    }
    
    stmntsRed = sort!(wCmp, SwapStrategy.stable)(statements).release;

    return stmntsRed;
}

// TODO: Honestly all contains should be a kind-of `MStatementSearchable` and `MStatementReplaceable`
// AND MCloneable
/** 
 * Represents any sort of type
 * that can store `Statement`(s)
 * (AST nodes) and retrieve them
 * again at a later stage
 *
 * Additionally also means that
 * the `MStatementSearchable` and
 * `MStatementReplaceable` types
 * are implemented
 */
public interface Container : MStatementSearchable, MStatementReplaceable
{
    /** 
     * Appends the given statement to
     * this container's body
     *
     * Params:
     *   statement = the `Statement`
     * to add
     */
    public void addStatement(Statement statement);

    /** 
     * Appends the list of statements
     * (in order) to this container's
     * body
     *
     * Params:
     *   statements = the `Statement[]`
     * to add
     */
    public void addStatements(Statement[] statements);

    /** 
     * Returns the body of this
     * container
     *
     * Returns: a `Statement[]`
     */
    public Statement[] getStatements();
}


public class Module : Entity, Container
{
    /** 
     * Path to the module on disk
     */
    private string moduleFilePath;

    this(string moduleName)
    {
        super(moduleName);
    }

    /** 
     * Returns the file system path where
     * this module was parsed from
     *
     * Returns: the path as a `string`
     */
    public string getFilePath()
    {
        return this.moduleFilePath;
    }

    /** 
     * Sets the file system path to the module
     *
     * Params:
     *   filePath = path to the module on disk
     */
    public void setFilePath(string filePath)
    {
        this.moduleFilePath = filePath;
    }

    private Statement[] statements;


    public void addStatement(Statement statement)
    {
        this.statements ~= statement;
    }

    public void addStatements(Statement[] statements)
    {
        this.statements ~= statements;
    }

    public Statement[] getStatements()
    {
        // TODO: Holy naai this is expensive
        return weightReorder(statements);
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
                    statements[idx] = that;

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

    /** 
     * Provides a string representation of
     * this module
     *
     * Returns: a string
     */
    public override string toString()
    {
        return "Module [name: "~getName()~"]";
    }
}

/**
* Struct
*
* A Struct can only contain Entity's
* that are Variables (TODO: Enforce in parser)
* TODO: Possibly enforce here too
*/
public class Struct : Type, Container, MCloneable
{
    private Statement[] statements;

    public void addStatement(Statement statement)
    {
        this.statements ~= statement;
    }

    public void addStatements(Statement[] statements)
    {
        this.statements ~= statements;
    }

    public Statement[] getStatements()
    {
        // TODO: Holy naai this is expensive
        return weightReorder(statements);
    }

    this(string name)
    {
        super(name);
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
                    statements[idx] = that;

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

    /** 
     * Clones this struct recursively returning a
     * fresh copy of all its members and the struct
     * itself.
     *
     * Param:
     *   newParent = the `Container` to re-parent the
     *   cloned `Statement`'s self to
     *
     * Returns: the cloned `Statement`
     */
    public override Statement clone(Container newParent = null)
    {
        Struct clonedStruct = new Struct(this.name);

        /** 
         * Clone all the statements and re-parent them
         * to the clone
         */
        Statement[] clonedStatements;
        foreach(Statement curStmt; this.getStatements())
        {
            Statement clonedStmt;
            if(cast(MCloneable)curStmt)
            {
                MCloneable cloneableCurStmt = cast(MCloneable)curStmt;
                clonedStmt = cloneableCurStmt.clone();
            }

            // Re-parent to the cloned struct
            clonedStmt.parentTo(clonedStruct);

            // Add it to the cloned struct's body
            clonedStruct.addStatement(clonedStmt);
        }

        // Parent ourselves to the given parent
        clonedStruct.parentTo(newParent);

        return clonedStruct;
    }
}

public class Clazz : Type, Container
{
    private Statement[] statements;

    private string[] interfacesClasses;

    this(string name)
    {
        super(name);

        /* Weighted as 0 */
        weight = 0;
    }

    public void addInherit(string[] l)
    {
        interfacesClasses ~= l;
    }

    public string[] getInherit()
    {
        return interfacesClasses;
    }

    public override string toString()
    {
        return "Class (Name: "~name~", Parents (Class/Interfaces): "~to!(string)(interfacesClasses)~")";
    }

    public void addStatement(Statement statement)
    {
        this.statements ~= statement;
    }

    public void addStatements(Statement[] statements)
    {
        this.statements ~= statements;
    }

    public Statement[] getStatements()
    {
        // TODO: Holy naai this is expensive
        return weightReorder(statements);
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
                    statements[idx] = that;

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


/**
 * Test the `MCloneable`-ity support of `Struct`
 * which has two `Variable` members (therefore
 * also testing the `clone()` on `Variable`)
 */
unittest
{
    Struct original = new Struct("User");
    Variable originalVar_Name = new Variable("byte*", "name");
    Variable originalVar_Age = new Variable("int", "age");
    originalVar_Name.parentTo(original);
    originalVar_Age.parentTo(original);
    original.addStatement(originalVar_Name);
    original.addStatement(originalVar_Age);
    
    // Now clone it
    Struct cloned = cast(Struct)original.clone();

    // Cloned version should differ
    assert(cloned !is original);

    // Cloned statements versus original statements
    Statement[] clonedStmts = cloned.getStatements();
    Statement[] originalStmts = original.getStatements();
    assert(clonedStmts[0] !is originalStmts[0]);
    assert(clonedStmts[1] !is originalStmts[1]);

    // Compare the variables (members) of both
    Variable origStruct_MemberOne = cast(Variable)originalStmts[0];
    Variable origStruct_MemberTwo = cast(Variable)originalStmts[1];
    Variable clonedStruct_MemberOne = cast(Variable)clonedStmts[0];
    Variable clonedStruct_MemberTwo = cast(Variable)clonedStmts[1];
    assert(origStruct_MemberOne !is clonedStruct_MemberOne);
    assert(origStruct_MemberTwo !is clonedStruct_MemberTwo);
    assert(originalVar_Name.getName() == clonedStruct_MemberOne.getName()); // Names should match
    assert(origStruct_MemberTwo.getName() == clonedStruct_MemberTwo.getName()); // Names should match

    // Ensure re-parenting is correct
    assert(origStruct_MemberOne.parentOf() == original);
    assert(origStruct_MemberTwo.parentOf() == original);
    assert(clonedStruct_MemberOne.parentOf() == cloned);
    assert(clonedStruct_MemberTwo.parentOf() == cloned);

    // TODO: Make this more deeper this test as a few
    // ... more things were left out that can be checked
}