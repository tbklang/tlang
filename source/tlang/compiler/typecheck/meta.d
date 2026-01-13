module tlang.compiler.typecheck.meta;

import tlang.compiler.symbols.data : Statement, TypedEntity, Function, FunctionCall, IdentExpression;
import tlang.compiler.symbols.expressions : Expression;
import tlang.compiler.symbols.typing.core;
import tlang.compiler.symbols.containers : Container;
import tlang.compiler.symbols.mcro;
import tlang.compiler.typecheck.core;
import tlang.misc.logging;
import std.conv : to;
import tlang.compiler.configuration;
import tlang.compiler.symbols.aliases : AliasDeclaration;
import std.string : format;

import tlang.misc.exceptions : TError;
import tlang.compiler.typecheck.size_t;

/**
 * Represents an exception that
 * occurs during meta processing
 */
public class MetaException : TError
{
    this(string msg)
    {
        super(format("MetaException: %s", msg));
    }
}

/** 
 * The `MetaProcessor` is used to do a pass over a `Container`
 * to process any macro and macro-like entities
 */
public class MetaProcessor
{
    private TypeChecker tc;
    private bool isMetaEnabled;
    private CompilerConfiguration compilerConfig;

    /** 
     * Constructs a new `MetaProcessor` for the purposes of
     * modifying the AST tree before the typechecker traverses
     * it
     *
     * Params:
     *   tc = the `TypeChecker` instance to process
     *   isMetaEnabled = `true` if to perform meta processing, otherwise `false`
     */
    this(TypeChecker tc, bool isMetaEnabled)
    {
        this.tc = tc;
        this.isMetaEnabled = isMetaEnabled;
        this.compilerConfig = tc.getConfig();
    }

    /** 
     * Analyzes the provided `Container` and searches for any `Macro`-like
     * parse-nodes to process
     */
    public void process(Container container)
    {
        /* Only apply meta-processing if enabled */
        if(!isMetaEnabled)
        {
            return;
        }

        /* Get all statements */
        Statement[] stmts = container.getStatements();

        foreach(Statement curStmt; stmts)
        {
            DEBUG("MetaProcessor: Examining AST node '"~curStmt.toString()~"'...");

            /** 
             * If the current statement is a Container then recurse
             * 
             * This will help us do the following:
             *
             * 1. Type re-writing of
             *      a. Functions (Parameters and Body as both make up its Statement[])
             */
            if(cast(Container)curStmt)
            {
                process(cast(Container)curStmt);
            }
        }
    }

    import niknaks.arrays : filter;
    import niknaks.functional : predicateOf, Predicate;
    import tlang.compiler.symbols.data : VariableExpression;
    import std.string : cmp;

    import tlang.compiler.typecheck.resolution : Resolver;

    private VariableExpression[] getNameReferences(Container c, Expression e)
    {
        // if it is a `variableExpression` then grab its name directly
        // (TODO: See if we should just be checking `IdentExpression` rather)
        auto e_ve = cast(VariableExpression)e;
        if(e_ve)
        {
            return [e_ve];
        }

        // else, try search the expression `e` for `VariableExpression`(s)
        // and collect the names
        auto e_mss = cast(MStatementSearchable)e;
        if(e_mss)
        {
            VariableExpression[] n_s;
            foreach(n; cast(VariableExpression[])e_mss.search(VariableExpression.classinfo))
            {
                n_s ~= getNameReferences(c, n);
            }
            return n_s;
        }

        return [];
    }
}