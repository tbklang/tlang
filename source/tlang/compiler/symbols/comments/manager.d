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

public final class CommentManager // TODO: Make a sruct
{
    private SList!(Comment) _stk;

    this()
    {

    }

    public void pushComment(Token comment)
    {
        pushComment(Comment.fromToken(comment));
    }

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