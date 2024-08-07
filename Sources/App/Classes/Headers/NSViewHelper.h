/* *********************************************************************
 *                  _____         _               _
 *                 |_   _|____  _| |_ _   _  __ _| |
 *                   | |/ _ \ \/ / __| | | |/ _` | |
 *                   | |  __/>  <| |_| |_| | (_| | |
 *                   |_|\___/_/\_\\__|\__,_|\__,_|_|
 *
 * Copyright (c) 2010 - 2020 Codeux Software, LLC & respective contributors.
 *       Please see Acknowledgements.pdf for additional information.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 *  * Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *  * Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *  * Neither the name of Textual, "Codeux Software, LLC", nor the
 *    names of its contributors may be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *********************************************************************** */

NS_ASSUME_NONNULL_BEGIN

@interface NSWindow (TXWindowHelper)
/* Reset size of window to accommodate -minSize */
- (void)changeFrameToMin; // display = YES; animate = NO
- (void)changeFrameToMinAndDisplay:(BOOL)display; // animate = NO
- (void)changeFrameToMinAndDisplay:(BOOL)display animate:(BOOL)animate;

/* Sets content view to nil, resets frame to fit view, then assigns new view. */
- (void)replaceContentView:(NSView *)withView;
@end

@interface NSView (TXViewHelper)
/* Self top, right, bottom, left will = superview with 0.0 constant. */
- (void)addConstraintsToSuperviewToHugEdges;

/* Superview width and height will = self with 0.0 constant. */
/* A priority of 550 is used to encourage hugging. */
- (void)addConstraintsToSuperviewToEqualDimensions;

/* Remove first subview (if one is present) and replaces it with subview. */
/* The new superview width and height will equal that of subview with a
 priority of 550. The subview top, right, bottom, and left will equal
 that of the superview with 0.0 constant. */
/* See 	-addConstraintsToSuperviewToHugEdges
		-addConstraintsToSuperviewToEqualDimensions */
- (void)replaceFirstSubview:(NSView *)withView;
@end

NS_ASSUME_NONNULL_END
