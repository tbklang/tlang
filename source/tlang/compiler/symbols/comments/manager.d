/**
 * Comment manager
 *
 * Authors: Tristan Brice Velloza Kildaire (deavmi)
 */
module tlang.compiler.symbols.comments.manager;

import tlang.compiler.lexer.core.tokens : Token;
import tlang.compiler.symbols.comments : Comment;

import std.container.slist : SList;
import niknaks.functional : Optional;

/** 
 * Comment manager
 */
public final class CommentManager // TODO: Make a sruct
{
    private SList!(Comment) _stk;

    this()
    {

    }

    /** 
     * Pushes the given token onto the top
     * fo the stack by first converting it 
     * to a `Comment`
     *
     * Params:
     *   comment = the token comment
     */
    public void pushComment(Token comment)
    {
        pushComment(Comment.fromToken(comment));
    }

    /** 
     * Pushes a comment onto the top
     * fo the stack
     *
     * Params:
     *   comment = the comment
     */
    public void pushComment(Comment comment)
    {
        _stk.insertFront(comment);
    }

    public Optional!(Comment) popComment()
    {
        if(_stk.empty())
        {
            return Optional!(Comment).empty();
        }

        Comment c = _stk.front();
        // import std.range : popFront;
        _stk.linearRemoveElement(c);
        return Optional!(Comment)(c);
    }
}