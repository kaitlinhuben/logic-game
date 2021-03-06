{--
    Contains main functions to render view
--}
module View.View where 

import Array
import Dict
import List ((::))
import Graphics.Element (..)
import Graphics.Collage (Form, collage, toForm, move)
import Graphics.Input (clickable)
import Maybe (withDefault)
import Signal (send)
import Html (a, button, text, toElement, fromElement, img, h2)
import Html.Attributes (href, id, src)
import Model.Model (..)
import View.Nets (..)

-- don't technically need Text.asText, but clickable doesn't work without it!
import Text

{------------------------------------------------------------------------------
    Display entire page
------------------------------------------------------------------------------}
display : (Int, Int) -> GameState -> Element
display (w,h) gameState = 
  let
      upperBarHeight = 50
      mainHeight = h - upperBarHeight
      upperBar = drawNavBar (w, upperBarHeight) gameState
      mainContent = drawMainContent (w, mainHeight) gameState
  in
      flow down [upperBar, mainContent]

drawNavBar : (Int, Int) -> GameState -> Element
drawNavBar (w,h) gameState = 
  let
    -- stats: clicks, score, par, etc.
    clicksText = Text.plainText ("Clicks: " ++ (toString gameState.clicks))
    parText = Text.plainText ("Par: " ++ (toString gameState.clicksPar))
  in
    flow down [parText, clicksText]

drawMainContent : (Int, Int) -> GameState -> Element
drawMainContent (w,h) gameState = 
  let 
    circuitElement = drawCircuit (w,h) gameState
    circuitContainer = container w h middle circuitElement
  in
    if | gameState.completed == False -> circuitContainer
       | otherwise -> 
          let
            completedText = Text.centered (Text.height 40 (Text.fromString "You completed the level!"))
            parText = Text.centered (Text.height 20 (Text.fromString (if gameState.clicks <= gameState.clicksPar then "You were at or under par. Good job!" else "You were above par; give it another try.")))
            nextBtnHTML = a 
              [ href gameState.nextLink ] 
              [ img [src nextLevelBtn] [] ]
            levelNextButton = toElement 50 50 nextBtnHTML
          in
            flow down 
            [ 
              flow right [ completedText, levelNextButton]
            , parText
            , circuitContainer 
            ]

{------------------------------------------------------------------------------
    Draw the whole circuit
------------------------------------------------------------------------------}
drawCircuit : (Int,Int) -> GameState -> Element
drawCircuit (w,h) gs = 
  let 
    netsForms = drawAll drawNets gs.nonInputNames gs
    inputsForms = drawAll drawInputGate gs.inputNames gs
    solutionsForms = drawAll drawSolution (Dict.keys gs.solution) gs
    otherForms = drawAll drawGate gs.nonInputNames gs

    allForms = netsForms ++ inputsForms ++ solutionsForms ++ otherForms
  in
    collage w h allForms

{------------------------------------------------------------------------------
    Generic recursive function that allows you to draw all of a certain thing
    Takes as parameters:
      - The function to draw a single item
      - The List of names to iterate over
      - The GameState to pass to the drawSingle function
------------------------------------------------------------------------------}
drawAll : (String->GameState->Form) -> List String -> GameState -> List Form
drawAll drawSingle names gs =
  case names of 
    [] -> []
    name :: [] -> [drawSingle name gs]
    name :: tl -> 
      let
        singleForm = drawSingle name gs
        tlForms = drawAll drawSingle tl gs 
      in
        singleForm :: tlForms

-- Draw incoming nets to a gate
drawNets : String -> GameState -> Form
drawNets name gs =
  let 
    circuit = gs.circuitState
    gate = getGate name circuit 
  in
    if | Array.length gate.inputs == 1 -> drawNetToSingle name gs
       | otherwise -> drawNetsToDouble name gs

-- Draw a single gate
drawGate : String -> GameState -> Form
drawGate name gs = 
  let
    gate = getGate name gs.circuitState
    (w,h) = gate.imgSize
    imgForm = toForm(image w h gate.imgName)
  in 
    move gate.location imgForm

-- Draw the solution (e.g. whether output is correct or not)
drawSolution : String -> GameState -> Form
drawSolution name gs = 
  let
    gate = getGate name gs.circuitState
    gateSolution = withDefault False (Dict.get name gs.solution)
    (w,h) = solutionSize
    solutionImg = if | gate.status == gateSolution -> outputGoodName
                     | otherwise -> outputBadName
    imgForm = toForm(image w h solutionImg)
    (x,y) = gate.location
  in 
    move (x,y-25) imgForm

-- Draw a single input gate
drawInputGate : String -> GameState -> Form
drawInputGate name gs = 
  let
    -- get the gate
    gate = getGate name gs.circuitState

    -- get the input channel associated with the gate
    gateChannel = withDefault failedChannel (Dict.get name gs.inputChannels)
    
    -- get the size and set up the image
    (w,h) = gate.imgSize
    gateImage = image w h gate.imgName

    -- if the input is currently True, a click should send False
    -- if input currently False, click should send True
    -- (values should switch)
    updateValue = if | gate.status==True -> False
                     | otherwise -> True

    -- make the image a clickable element
    gateElement = clickable (send gateChannel updateValue) gateImage

    -- make the clickable image a link so cursor switches to pointer
    linkedElement = link "#" gateElement
  in 
    move gate.location (toForm linkedElement)