//
//  VectorImageView.swift
//  SWFShapeDraw
//
//  Created by larryhou on 25/9/2015.
//  Copyright © 2015 larryhou. All rights reserved.
//
import Foundation
import UIKit

class VectorImageView:UIView
{
    struct StyleState:OptionSetType
    {
        let rawValue:Int
        init(rawValue:Int) { self.rawValue = rawValue }
        
        static let SolidStroke    = StyleState(rawValue: 1 << 0)
        static let GradientStroke = StyleState(rawValue: 1 << 1)
        static let SolidFill      = StyleState(rawValue: 1 << 2)
        static let GradientFill   = StyleState(rawValue: 1 << 3)
        
        static let Stroke:StyleState = [StyleState.SolidStroke, StyleState.GradientStroke]
        static let Fill:StyleState   = [StyleState.SolidFill,   StyleState.GradientFill]
    }
    
    struct GraphicsAction:OptionSetType
    {
        let rawValue:Int
        init(rawValue:Int) { self.rawValue = rawValue }
        
        static let LineStyle         = GraphicsAction(rawValue: 1 << 0)
        static let LineGradientStyle = GraphicsAction(rawValue: 1 << 1)
        static let BeginFill         = GraphicsAction(rawValue: 1 << 2)
        static let BeginGradientFill = GraphicsAction(rawValue: 1 << 3)
        static let EndFill           = GraphicsAction(rawValue: 1 << 4)
        static let MoveTo            = GraphicsAction(rawValue: 1 << 5)
        static let LineTo            = GraphicsAction(rawValue: 1 << 6)
        static let CurveTo           = GraphicsAction(rawValue: 1 << 7)
        
        static let ChangeLineStyle:GraphicsAction = [GraphicsAction.LineStyle, GraphicsAction.LineGradientStyle]
        static let ChangeFillStyle:GraphicsAction = [GraphicsAction.BeginFill, GraphicsAction.BeginGradientFill]
        static let ChangeStyle:GraphicsAction = [GraphicsAction.ChangeLineStyle, GraphicsAction.ChangeFillStyle]
        
        static func from(method:String) -> GraphicsAction?
        {
            switch method
            {
                case "MOVE_TO"             :return GraphicsAction.MoveTo
                case "LINE_TO"             :return GraphicsAction.LineTo
                case "CURVE_TO"            :return GraphicsAction.CurveTo
                case "LINE_STYLE"          :return GraphicsAction.LineStyle
                case "LINE_GRADIENT_STYLE" :return GraphicsAction.LineGradientStyle
                case "BEGIN_FILL"          :return GraphicsAction.BeginFill
                case "BEGIN_GRADIENT_FILL" :return GraphicsAction.BeginGradientFill
                case "END_FILL"            :return GraphicsAction.EndFill
                default:return nil
            }
        }
    }
    
    private var state:StyleState!
    private var path:CGMutablePath!
    private var style:NSDictionary!
    private var lineWidth:CGFloat = 1.0
    private var lineJoin = CGLineJoin.Round
    private var lineCap = CGLineCap.Round
    private var miterLimit:CGFloat = 3.0
    
    var steps:[(method:String, params:NSDictionary)]!
    var iframe:CGRect!
    
    //MARK: import
    func importVectorGraphics(graphics:NSArray)
    {
        func union(inout rect:(left:CGFloat, top:CGFloat, right:CGFloat, bottom:CGFloat), x:CGFloat, y:CGFloat)
        {
            rect.left   = min(x, rect.left)
            rect.right  = max(x, rect.right)
            rect.top    = min(y, rect.top)
            rect.bottom = max(y, rect.bottom)
        }
        
        steps = []
        
        var rect:(left:CGFloat, top:CGFloat, right:CGFloat, bottom:CGFloat) = (0,0,0,0)
        for i in 0..<graphics.count
        {
            let data = graphics[i] as! NSArray
            let method = data.objectAtIndex(0) as! String
            let params = data.objectAtIndex(1) as! NSDictionary
            
            if let action = GraphicsAction.from(method)
            {
                steps.append((method, params))
                
                var x:CGFloat = 0.0, y:CGFloat = 0.0
                switch action
                {
                    case GraphicsAction.MoveTo, GraphicsAction.LineTo:
                        x = CGFloat(params.valueForKey("x") as! Double)
                        y = CGFloat(params.valueForKey("y") as! Double)
                        union(&rect, x: x, y: y)
                        
                    case GraphicsAction.CurveTo:
                        x = CGFloat(params.valueForKey("anchorX") as! Double)
                        y = CGFloat(params.valueForKey("anchorY") as! Double)
                        union(&rect, x: x, y: y)
                        
                        x = CGFloat(params.valueForKey("controlX") as! Double)
                        y = CGFloat(params.valueForKey("controlY") as! Double)
                        union(&rect, x: x, y: y)
                    default:break
                }
            }
            else
            {
                print("SKIP", method, params)
            }
        }
        
        iframe = CGRectMake(rect.left, rect.top, rect.right - rect.left, rect.bottom - rect.top)
    }
    
    //MARK: utils
    func getValue(params:NSDictionary, key:String) -> AnyObject?
    {
        let data = params.valueForKeyPath(key)
        if let data = data where data is NSNull
        {
            return nil
        }
        
        return data
    }
    
    func getCGFloat(params:NSDictionary, key:String, dftValue:CGFloat = 0.0) -> CGFloat
    {
        if let data = getValue(params, key: key)
        {
            return CGFloat(data as! Double)
            
        }
        
        return dftValue
    }
    
    func getUIColor(params:NSDictionary, colorKey:String, alphaKey:String) -> UIColor
    {
        let rgbColor:Int
        if let data = getValue(params, key: colorKey)
        {
            rgbColor = data as! Int
        }
        else
        {
            rgbColor = 0
        }
        
        let b = (rgbColor >> 00) & 0xFF
        let g = (rgbColor >> 08) & 0xFF
        let r = (rgbColor >> 16) & 0xFF
        
        let a:CGFloat
        if let data = getValue(params, key: alphaKey)
        {
            a = CGFloat(data as! Double)
        }
        else
        {
            a = 1.0
        }
        
        let color = UIColor(red: CGFloat(r)/0xFF, green: CGFloat(g)/0xFF, blue: CGFloat(b)/0xFF, alpha: a)
        return color
    }
    
    //MARK: draw
    override func drawRect(rect: CGRect)
    {
        let context = UIGraphicsGetCurrentContext()
        
        let margin:CGFloat = 0.0
        let scale = min((rect.width - margin) / iframe.width, (rect.height - margin) / iframe.height)
        CGContextScaleCTM(context, scale, scale)
        
        let translateX = -(iframe.origin.x + iframe.width  / 2) + rect.width  / 2 / scale
        let translateY = -(iframe.origin.y + iframe.height / 2) + rect.height / 2 / scale
        CGContextTranslateCTM(context, translateX, translateY)
        
        for i in 0..<steps.count
        {
            let step = steps[i]
            if let action = GraphicsAction.from(step.method)
            {
                let params = step.params
                if GraphicsAction.ChangeStyle.contains(action) || action == GraphicsAction.EndFill
                {
                    flushContext(context)
                }
                
                switch action
                {
                    case GraphicsAction.LineStyle:
                        state = StyleState.SolidStroke
                        style = params
                        
                        path = CGPathCreateMutable()
                        
                    case GraphicsAction.LineGradientStyle:
                        state = StyleState.GradientStroke
                        style = params
                        
                        path = CGPathCreateMutable()
                        
                    case GraphicsAction.LineTo:
                        CGPathAddLineToPoint(path, nil,
                            getCGFloat(params, key: "x"), getCGFloat(params, key: "y"))
                        
                    case GraphicsAction.MoveTo:
                        CGPathMoveToPoint(path, nil,
                            getCGFloat(params, key: "x"), getCGFloat(params, key: "y"))
                        
                    case GraphicsAction.CurveTo:
                        CGPathAddQuadCurveToPoint(path, nil,
                            getCGFloat(params, key: "controlX"), getCGFloat(params, key: "controlY"),
                            getCGFloat(params, key: "anchorX"),  getCGFloat(params, key: "anchorY"))
                        
                    case GraphicsAction.BeginFill:
                        state = StyleState.SolidFill
                        style = params
                        
                        path = CGPathCreateMutable()
                        
                    case GraphicsAction.BeginGradientFill:
                        state = StyleState.GradientFill
                        style = params
                        
                        path = CGPathCreateMutable()
                        
                    case GraphicsAction.EndFill:break
                    default:break
                }
            }
        }
        
        flushContext(context)
    }
    
    func flushContext(context:CGContext?)
    {
        if state == nil || path == nil
        {
            return
        }
        
        if StyleState.Fill.contains(state)
        {
            if state == StyleState.GradientFill
            {
                CGContextSaveGState(context)
                CGContextAddPath(context, path)
                CGContextClip(context)
                fillContextWithGradientStyle(context, params: style)
                CGContextRestoreGState(context)
            }
            else
            {
                CGContextAddPath(context, path)
                let color = getUIColor(style, colorKey: "color", alphaKey: "alpha")
                CGContextSetFillColorWithColor(context, color.CGColor)
                CGContextFillPath(context)
            }
        }
        else
        if StyleState.Stroke.contains(state)
        {
            if (state == StyleState.GradientStroke)
            {
                CGContextSaveGState(context)
                strokeContextWithGradientStyle(context, path: path)
                CGContextRestoreGState(context)
            }
            else
            {
                CGContextAddPath(context, path)
                setContextStrokeStyle(context, params: style)
                CGContextStrokePath(context)
            }
        }
        
        path = nil
    }
    
    func setContextStrokeStyle(context:CGContext?, params:NSDictionary)
    {
        let color = getUIColor(params, colorKey: "color", alphaKey: "alpha")
        CGContextSetStrokeColorWithColor(context, color.CGColor)
        
        lineWidth = getCGFloat(params, key: "thickness", dftValue: 0.0)
        CGContextSetLineWidth(context, lineWidth)
        
        if let data = getValue(params, key: "caps")
        {
            let type = data as! String
            switch type
            {
                case "square": lineCap = CGLineCap.Square
                case "round" : lineCap = CGLineCap.Round
                default: lineCap = CGLineCap.Butt
            }
        }
        else
        {
            lineCap = CGLineCap.Butt
        }
        
        CGContextSetLineCap(context, lineCap)
        
        if let data = getValue(params, key: "joints")
        {
            let type = data as! String
            switch type
            {
                case "bevel": lineJoin = CGLineJoin.Bevel
                case "miter": lineJoin = CGLineJoin.Miter
                default:lineJoin = CGLineJoin.Round
            }
        }
        else
        {
            lineJoin = CGLineJoin.Round
        }
        
        CGContextSetLineJoin(context, lineJoin)
        
        miterLimit = getCGFloat(params, key: "miterLimit", dftValue: 3.0)
        CGContextSetMiterLimit(context, miterLimit)
    }
    
    func strokeContextWithGradientStyle(context:CGContext?, path:CGMutablePath)
    {
        let gradientPath = CGPathCreateCopyByStrokingPath(path, nil, lineWidth, lineCap, lineJoin, miterLimit)
        CGContextAddPath(context, gradientPath)
        CGContextClip(context)
        
        fillContextWithGradientStyle(context, params: style)
    }
    
    func fillContextWithGradientStyle(context:CGContext?, params:NSDictionary)
    {
        let colors = params.valueForKey("colors") as! [Int]
        let alphas = params.valueForKey("alphas") as! [Double]
        
        var rgbaColors:[UIColor] = []
        for i in 0..<colors.count
        {
            let rgbColor = colors[i]
            let b = (rgbColor >> 00) & 0xFF
            let g = (rgbColor >> 08) & 0xFF
            let r = (rgbColor >> 16) & 0xFF
            let color = UIColor(red: CGFloat(r)/0xFF, green: CGFloat(g)/0xFF, blue: CGFloat(b)/0xFF, alpha: CGFloat(alphas[i]))
            rgbaColors.append(color)
        }
        
        var locations = (params.valueForKey("ratios") as! [Int]).map({ CGFloat($0) / 0xFF })
        let gradient = CGGradientCreateWithColors(CGColorSpaceCreateDeviceRGB(), rgbaColors.map({$0.CGColor}), &locations)
        
        var matrix:(a:CGFloat, b:CGFloat, c:CGFloat, d:CGFloat, tx:CGFloat, ty:CGFloat) = (0,0,0,0,0,0)
        matrix.a  = getCGFloat(params, key: "matrix.a")
        matrix.b  = getCGFloat(params, key: "matrix.b")
        matrix.c  = getCGFloat(params, key: "matrix.c")
        matrix.d  = getCGFloat(params, key: "matrix.d")
        matrix.tx = getCGFloat(params, key: "matrix.tx")
        matrix.ty = getCGFloat(params, key: "matrix.ty")
        
        let angle = atan2(matrix.b, matrix.a)
        
        let scaleX = matrix.a / cos(angle)
        let scaleY = matrix.d / cos(angle)
        let width = scaleX * 1638.4, height = scaleY * 1638.4
        
        let focalPointRatio = getCGFloat(params, key: "focalPointRatio")
        let type = params.valueForKey("type") as! String
        if type == "radial"
        {
            let radius = max(width / 2, height / 2);
            let startCenter = CGPointMake(width / 2 * cos(angle) * focalPointRatio + matrix.tx,
                                         height / 2 * sin(angle) * focalPointRatio + matrix.ty)
            let endCenter = CGPointMake(matrix.tx, matrix.ty)
            
            CGContextDrawRadialGradient(context, gradient, startCenter, 0, endCenter, radius,
                [CGGradientDrawingOptions.DrawsAfterEndLocation])
        }
        else
        {
            let sp = CGPointMake(-819.2 * scaleX, 0)
            let startPoint = CGPointMake(sp.x * cos(angle) - sp.y * sin(angle) + matrix.tx,
                                         sp.x * sin(angle) + sp.y * cos(angle) + matrix.ty)
            let ep = CGPointMake( 819.2 * scaleX, 0)
            let endPoint = CGPointMake(ep.x * cos(angle) - ep.y * sin(angle) + matrix.tx,
                                       ep.x * sin(angle) + ep.y * cos(angle) + matrix.ty)
            
            CGContextDrawLinearGradient(context, gradient, startPoint, endPoint,
                [CGGradientDrawingOptions.DrawsBeforeStartLocation, CGGradientDrawingOptions.DrawsAfterEndLocation])
        }
    }
}
