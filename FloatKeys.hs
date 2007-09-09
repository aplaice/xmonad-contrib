{-# OPTIONS_GHC -fglasgow-exts #-}
-----------------------------------------------------------------------------
-- |
-- Module       : XMonadContrib.FloatKeys
-- Copyright    : (c) Karsten Schoelzel <kuser@gmx.de>
-- License      : BSD
--
-- Maintainer   : Karsten Schoelzel <kuser@gmx.de>
-- Stability    : unstable
-- Portability  : unportable
--
-- Move and resize floating windows.
-----------------------------------------------------------------------------

module XMonadContrib.FloatKeys (
                -- * Usage
                -- $usage
                keysMoveWindow,
                keysMoveWindowTo,
                keysResizeWindow,
                keysAbsResizeWindow) where

import Operations
import XMonad
import Graphics.X11.Xlib
import Graphics.X11.Xlib.Extras

-- $usage
-- > import XMonadContrib.FloatKeys
--
-- >  , ((modMask,               xK_d     ), withFocused (keysResizeWindow (-10,-10) (1,1))) 
-- >  , ((modMask,               xK_s     ), withFocused (keysResizeWindow (10,10) (1,1))) 
-- >  , ((modMask .|. shiftMask, xK_d     ), withFocused (keysAbsResizeWindow (-10,-10) (1024,752))) 
-- >  , ((modMask .|. shiftMask, xK_s     ), withFocused (keysAbsResizeWindow (10,10) (1024,752))) 
-- >  , ((modMask,               xK_a     ), withFocused (keysMoveWindowTo (512,384) (1%2,1%2)))
--
--
-- keysMoveWindow (dx, dy) moves the window by dx pixels to the right and dy pixels down
--
-- keysMoveWindowTo (x, y) (gx, gy) moves the window relative point (gx, gy) to the point (x,y)
--      where (gx,gy) gives a position relative to the window border, i.e.
--      gx = 0 is the left border and gx = 1 the right border
--      gy = 0 is the top border  and gy = 1 the bottom border
--
--      examples on a 1024x768 screen: keysMoveWindowTo (512,384) (1%2, 1%2) centers the window on screen
--                                     keysMoveWindowTo (1024,0) (1, 0) puts it into the top right corner
--
-- keysResizeWindow (dx, dy) (gx, gy) changes the width by dx and the height by dy leaving the window
--      relative point (gx, gy) fixed
--
--      examples: keysResizeWindow (10, 0) (0, 0) makes the window 10 pixels larger to the right
--                keysResizeWindow (10, 0) (0, 1%2) does the same, unless sizeHints are applied
--                keysResizeWindow (10, 10) (1%2, 1%2) adds 5 pixels on each side
--                keysResizeWindow (-10, -10) (0, 1) shrinks the window in direction of the bottom-left corner
--              
--  keysAbsResizeWindow (dx, dy) (ax, ay) changes the width by dx and the height by dy leaving the screen
--      absolut point (ax, ay) fixed
--
--      examples on a 1024x768 screen: keysAbsResizeWindow (10, 10) (0, 0) enlarge the window and if it is not in the top-left corner it will also be moved away
--
keysMoveWindow :: D -> Window -> X ()
keysMoveWindow (dx,dy) w = whenX (isClient w) $ withDisplay $ \d -> do
    io $ raiseWindow d w
    wa <- io $ getWindowAttributes d w
    io $ moveWindow d w (fromIntegral (fromIntegral (wa_x wa) + dx))
                        (fromIntegral (fromIntegral (wa_y wa) + dy))
    float w

keysMoveWindowTo :: P -> G -> Window -> X ()
keysMoveWindowTo (x,y) (gx, gy) w = whenX (isClient w) $ withDisplay $ \d -> do
    io $ raiseWindow d w
    wa <- io $ getWindowAttributes d w
    io $ moveWindow d w (x - round (gx * fromIntegral (wa_width wa)))
                        (y - round (gy * fromIntegral (wa_height wa)))
    float w

type G = (Rational, Rational)
type P = (Position, Position)

keysResizeWindow :: D -> G -> Window -> X ()
keysResizeWindow = keysMoveResize keysResizeWindow'

keysAbsResizeWindow :: D -> D -> Window -> X ()
keysAbsResizeWindow = keysMoveResize keysAbsResizeWindow'

keysAbsResizeWindow' :: SizeHints -> P -> D -> D -> D -> (P,D)
keysAbsResizeWindow' sh (x,y) (w,h) (dx,dy) (ax, ay) = ((round nx, round ny), (nw, nh))
    where
        (nw, nh) = applySizeHints sh (w + dx, h + dy)
        nx :: Rational = fromIntegral (ax * w + nw * (fromIntegral x - ax)) / fromIntegral w
        ny :: Rational = fromIntegral (ay * h + nh * (fromIntegral y - ay)) / fromIntegral h

keysResizeWindow' :: SizeHints -> P -> D -> D -> G -> (P,D)
keysResizeWindow' sh (x,y) (w,h) (dx,dy) (gx, gy) = ((nx, ny), (nw, nh))
    where
        (nw, nh) = applySizeHints sh (w + dx, h + dy)
        nx = round $ fromIntegral x + gx * fromIntegral w - gx * fromIntegral nw
        ny = round $ fromIntegral y + gy * fromIntegral h - gy * fromIntegral nh

keysMoveResize :: (SizeHints -> P -> D -> a -> b -> (P,D)) -> a -> b -> Window -> X ()
keysMoveResize f move resize w = whenX (isClient w) $ withDisplay $ \d -> do
    io $ raiseWindow d w
    wa <- io $ getWindowAttributes d w
    sh <- io $ getWMNormalHints d w
    let wa_dim = (fromIntegral $ wa_width wa, fromIntegral $ wa_height wa)
        wa_pos = (fromIntegral $ wa_x wa, fromIntegral $ wa_y wa)
        (wn_pos, wn_dim) = f sh wa_pos wa_dim move resize 
    io $ resizeWindow d w `uncurry` wn_dim
    io $ moveWindow d w `uncurry` wn_pos
    float w
