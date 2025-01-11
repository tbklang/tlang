/**
 * Comment manager
 *
 * Authors: Tristan Brice Velloza Kildaire (deavmi)
 */
module tlang.compiler.symbols.comments.manager;

import tlang.compiler.lexer.core.tokens : Token;
import tlang.compiler.symbols.comments : Comment;

public final class CommentManager // TODO: Make a sruct
{
    this()
    {

    }

    public void pushComment(Token comment)
    {
        pushComment(Comment.fromToken(comment));
    }

    public void pushComment(Comment comment)
    {

    }
}