//
//  GraphView.swift
//  SWFShapeDraw
//
//  Created by larryhou on 22/8/2015.
//  Copyright © 2015 larryhou. All rights reserved.
//

import Foundation
import UIKit

class RedrawView:UIImageView
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
    
    struct DrawAction:OptionSetType
    {
        let rawValue:Int
        init(rawValue:Int) { self.rawValue = rawValue }
        
        static let LineStyle         = DrawAction(rawValue: 1 << 0)
        static let LineGradientStyle = DrawAction(rawValue: 1 << 1)
        static let BeginFill         = DrawAction(rawValue: 1 << 2)
        static let BeginGradientFill = DrawAction(rawValue: 1 << 3)
        static let EndFill           = DrawAction(rawValue: 1 << 4)
        static let MoveTo            = DrawAction(rawValue: 1 << 5)
        static let LineTo            = DrawAction(rawValue: 1 << 6)
        static let CurveTo           = DrawAction(rawValue: 1 << 7)
        
        static let ChangeLineStyle:DrawAction = [DrawAction.LineStyle, DrawAction.LineGradientStyle]
        static let ChangeFillStyle:DrawAction = [DrawAction.BeginFill, DrawAction.BeginGradientFill]
        static let ChangeStyle:DrawAction = [DrawAction.ChangeLineStyle, DrawAction.ChangeFillStyle]
        
        static func from(method:String) -> DrawAction?
        {
            switch method
            {
                case "MOVE_TO"             :return DrawAction.MoveTo
                case "LINE_TO"             :return DrawAction.LineTo
                case "CURVE_TO"            :return DrawAction.CurveTo
                case "LINE_STYLE"          :return DrawAction.LineStyle
                case "LINE_GRADIENT_STYLE" :return DrawAction.LineGradientStyle
                case "BEGIN_FILL"          :return DrawAction.BeginFill
                case "BEGIN_GRADIENT_FILL" :return DrawAction.BeginGradientFill
                case "END_FILL"            :return DrawAction.EndFill
                default:return nil
            }
        }
    }
    
    struct GradientStyleInfo
    {
        var type:String
        var gradient:CGGradient
        var matrix:(a:CGFloat, b:CGFloat, c:CGFloat, d:CGFloat, tx:CGFloat, ty:CGFloat)
        var focalPointRatio:CGFloat
    }
    
    private var state:StyleState!
    private var steps:[(method:String, params:NSDictionary)] = []
    
    private var path:CGMutablePath!
    private var style:NSDictionary!
    
    private var lineWidth:CGFloat = 1.0
    private var lineJoin = CGLineJoin.Round
    private var lineCap = CGLineCap.Round
    private var miterLimit:CGFloat = 3.0
    
    var irect:CGRect!
    
    var currentIndex:Int = 0
    var stepsAvaiable:Bool { return currentIndex < steps.count }
    
    func importSteps(data:[(method:String, params:NSDictionary)])
    {
        steps = data
        currentIndex = 0
    }
    
    func getUIColorCode(color:UIColor)->String
    {
        var r:CGFloat = 0, g:CGFloat = 0, b:CGFloat = 0, a:CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "UIColor(red:%.2f, green:%.2f, blue:%.2f, alpha:%.2f)", r, g, b, a)
    }
    
    func getGradientStyle(params:NSDictionary) -> GradientStyleInfo
    {
        let type = params.valueForKey("type") as! String
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
        
        let ratios = params.valueForKey("ratios") as! [Int]
        var locations = ratios.map({ CGFloat($0) / 0xFF })
        
        let gradient = CGGradientCreateWithColors(CGColorSpaceCreateDeviceRGB(), rgbaColors.map({$0.CGColor}), &locations)
        
        print("colors = [" + rgbaColors.map({ getUIColorCode($0) + ".CGColor" }).joinWithSeparator(",") + "]")
        print("locations = [" + locations.map({String(format:"%.4f", $0)}).joinWithSeparator(",") + "]")
        print("gradient = CGGradientCreateWithColors(CGColorSpaceCreateDeviceRGB(), colors, &locations)")
        
        var matrix:(a:CGFloat, b:CGFloat, c:CGFloat, d:CGFloat, tx:CGFloat, ty:CGFloat) = (0,0,0,0,0,0)
        matrix.a = CGFloat(params.valueForKeyPath("matrix.a") as! Double)
        matrix.b = CGFloat(params.valueForKeyPath("matrix.b") as! Double)
        matrix.c = CGFloat(params.valueForKeyPath("matrix.c") as! Double)
        matrix.d = CGFloat(params.valueForKeyPath("matrix.d") as! Double)
        matrix.tx = CGFloat(params.valueForKeyPath("matrix.tx") as! Double)
        matrix.ty = CGFloat(params.valueForKeyPath("matrix.ty") as! Double)
        
        let focalPointRatio = CGFloat(params.valueForKey("focalPointRatio") as! Double)
        return GradientStyleInfo(type: type, gradient: gradient!, matrix: matrix, focalPointRatio: focalPointRatio)
    }
    
    func getCoord(params:NSDictionary, key:String) -> CGFloat
    {
        if let data = getUnifyValue(params, key: key)
        {
            return CGFloat(data as! Double)
            
        }
        
        return 0.0
    }
    
    func getColor(params:NSDictionary, colorKey:String, alphaKey:String) -> UIColor
    {
        let rgbColor:Int
        if let data = getUnifyValue(params, key: colorKey)
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
        if let data = getUnifyValue(params, key: alphaKey)
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
    
    func drawNextRound()
    {
        let rect = bounds
        
        UIGraphicsBeginImageContextWithOptions(rect.size, false, UIScreen.mainScreen().scale)
        let context = UIGraphicsGetCurrentContext()
        if let image = self.image
        {
            image.drawInRect(rect)
        }
        
        let margin:CGFloat = 20.0
        let scale = min((rect.width - margin) / irect.width, (rect.height - margin) / irect.height)
        CGContextScaleCTM(context, scale, scale)
        
        let translateX = -(irect.origin.x + irect.width  / 2) + rect.width  / 2 / scale
        let translateY = -(irect.origin.y + irect.height / 2) + rect.height / 2 / scale
        CGContextTranslateCTM(context, translateX, translateY)
        
        if currentIndex == 0
        {
            print("let context = UIGraphicsGetCurrentContext()")
            print("var gradient:CGGradient!")
            print("var path:CGMutablePath!")
            print("var locations:[CGFloat]")
            print("var colors:[CGColor]")
            print("")
            
            print("CGContextSaveGState(context)")
            print(String(format: "let scale = min((rect.width - %.2f) / %.2f, (rect.height - %.2f) / %.2f)", margin, irect.width, margin, irect.height))
            print(String(format: "CGContextScaleCTM(context, scale, scale)"))
            
            print(String(format: "let translateX = -(%.2f + %.2f / 2) + rect.width  / 2 / scale", irect.origin.x, irect.width ))
            print(String(format: "let translateY = -(%.2f + %.2f / 2) + rect.height / 2 / scale", irect.origin.y, irect.height ))
            print("CGContextTranslateCTM(context, translateX, translateY)")
            print("")
        }
        
        var index = currentIndex
        while index < steps.count
        {
            let step = steps[index]
            if let action = DrawAction.from(step.method)
            {
                if DrawAction.ChangeStyle.contains(action) || action == DrawAction.EndFill
                {
                    if index > currentIndex
                    {
                        break
                    }
                }
            }
            
            drawStep(context, step: step)
            index++
        }
        
        flushCurrentContext(context)
        
        self.image = UIGraphicsGetImageFromCurrentImageContext()
        
        UIGraphicsEndImageContext()
        
        currentIndex = index
        if currentIndex == steps.count
        {
            print("CGContextRestoreGState(context)")
        }
    }
    
    func drawStep(context:CGContext?, step:(method:String, params:NSDictionary))
    {
        let params = step.params
        guard let action = DrawAction.from(step.method) else
        {
            return
        }
        
        switch action
        {
            case DrawAction.LineStyle:
                state = StyleState.SolidStroke
                style = params
                
                print("// BEGIN-SOLID-STROKE")
                
                path = CGPathCreateMutable()
                print("path = CGPathCreateMutable()")
            
            case DrawAction.LineGradientStyle:
                state = StyleState.GradientStroke
                style = params
                
                print("// BEGIN-GRADIENT-STROKE")
                
                path = CGPathCreateMutable()
                print("path = CGPathCreateMutable()")
            
            case DrawAction.LineTo:
                CGPathAddLineToPoint(path, nil,
                    getCoord(params, key: "x"), getCoord(params, key: "y"))
                print(String(format:"CGPathAddLineToPoint(path, nil, %6.2f, %6.2f)", getCoord(params, key: "x"), getCoord(params, key: "y")))
            
            case DrawAction.MoveTo:
                CGPathMoveToPoint(path, nil,
                    getCoord(params, key: "x"), getCoord(params, key: "y"))
                print(String(format:"CGPathMoveToPoint(path, nil, %6.2f, %6.2f)", getCoord(params, key: "x"), getCoord(params, key: "y")))
            
            case DrawAction.CurveTo:
                CGPathAddQuadCurveToPoint(path, nil,
                    getCoord(params, key: "controlX"), getCoord(params, key: "controlY"),
                    getCoord(params, key: "anchorX"),  getCoord(params, key: "anchorY"))
                print(String(format:"CGPathAddQuadCurveToPoint(path, nil, %6.2f, %6.2f, %6.2f, %6.2f)",
                    getCoord(params, key: "controlX"), getCoord(params, key: "controlY"),
                    getCoord(params, key: "anchorX"),  getCoord(params, key: "anchorY")))
                
            case DrawAction.BeginFill:
                state = StyleState.SolidFill
                style = params
                
                print("// BEGIN-SOLID-FILL")
                
                path = CGPathCreateMutable()
                print("path = CGPathCreateMutable()")
            
            case DrawAction.BeginGradientFill:
                state = StyleState.GradientFill
                style = params
                
                print("// BEGIN-GRADIENT-FILL")
                
                path = CGPathCreateMutable()
                print("path = CGPathCreateMutable()")
            
            case DrawAction.EndFill:break
            default:break
        }
    }
    
    func flushCurrentContext(context:CGContext?)
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
                print("CGContextSaveGState(context)")
                CGContextAddPath(context, path)
                print("CGContextAddPath(context, path)")
                CGContextClip(context)
                print("CGContextClip(context)")
                fillContextGradientStyle(context, params: style)
                CGContextRestoreGState(context)
                print("CGContextRestoreGState(context)")
                print("// END-GRADIENT-FILL")
            }
            else
            {
                CGContextAddPath(context, path)
                print("CGContextAddPath(context, path)")
                let color = getColor(style, colorKey: "color", alphaKey: "alpha")
                CGContextSetFillColorWithColor(context, color.CGColor)
                print(String(format: "CGContextSetFillColorWithColor(context, %@.CGColor)", getUIColorCode(color)))
                CGContextFillPath(context)
                print("CGContextFillPath(context)")
                print("// END-SOLID-FILL")
            }
        }
        else
        if StyleState.Stroke.contains(state)
        {
            if (state == StyleState.GradientStroke)
            {
                CGContextSaveGState(context)
                print("CGContextSaveGState(context)")
                strokePathWithGradientStyle(context, path: path)
                CGContextRestoreGState(context)
                print("CGContextRestoreGState(context)")
                print("// END-GRADIENT-STROKE")
            }
            else
            {
                CGContextAddPath(context, path)
                print("CGContextAddPath(context, path)")
                setContextLineSolidColorStyle(context, params: style)
                CGContextStrokePath(context)
                print("CGContextStrokePath(context)")
                print("// END-SOLID-STROKE")
            }
        }
        
        print("")
        path = nil
    }
    
    func setContextLineSolidColorStyle(context:CGContext?, params:NSDictionary)
    {
        let r:Int, g:Int, b:Int
        if let data = getUnifyValue(params, key: "color")
        {
            let rgbColor = data as! Int
            b = (rgbColor >> 00) & 0xFF
            g = (rgbColor >> 08) & 0xFF
            r = (rgbColor >> 16) & 0xFF
        }
        else
        {
            r = 0; g = 0; b = 0
        }
        
        var a:CGFloat = 1.0
        if let data = getUnifyValue(params, key: "alpha")
        {
            a = CGFloat(data as! Double)
        }
        
        let color = UIColor(red: CGFloat(r)/0xFF, green: CGFloat(g)/0xFF, blue: CGFloat(b)/0xFF, alpha: a)
        CGContextSetStrokeColorWithColor(context, color.CGColor)
        print(String(format: "CGContextSetStrokeColorWithColor(context, %@.CGColor)", getUIColorCode(color) as NSString))
        
        if let data = getUnifyValue(params, key: "thickness")
        {
            lineWidth = CGFloat(data as! Double)
        }
        else
        {
            lineWidth = 0.0
        }
        
        CGContextSetLineWidth(context, lineWidth)
        print(String(format: "CGContextSetLineWidth(context, %.2f)", lineWidth))
        
        if let data = getUnifyValue(params, key: "caps")
        {
            let type = data as! String
            switch type
            {
                case "square": lineCap = CGLineCap.Square
                case "round": lineCap = CGLineCap.Round
                default: lineCap = CGLineCap.Butt
            }
        }
        else
        {
            lineCap = CGLineCap.Butt
        }
        
        CGContextSetLineCap(context, lineCap)
        print(String(format: "CGContextSetLineCap(context, CGLineCap(rawValue:%d)!)", lineCap.rawValue))
        
        if let data = getUnifyValue(params, key: "joints")
        {
            let type = data as! String
            switch type
            {
                case "bevel": lineJoin = CGLineJoin.Bevel
                case "miter": lineJoin = CGLineJoin.Miter
                case "round":fallthrough
                default:lineJoin = CGLineJoin.Round
            }
        }
        else
        {
            lineJoin = CGLineJoin.Round
        }
        
        CGContextSetLineJoin(context, lineJoin)
        print(String(format: "CGContextSetLineJoin(context, CGLineJoin(rawValue:%d)!)", lineJoin.rawValue))
        
        if let data = getUnifyValue(params, key: "miterLimit")
        {
            miterLimit = CGFloat(data as! Double)
        }
        else
        {
            miterLimit = 3.0
        }
        
        CGContextSetMiterLimit(context, miterLimit)
        print(String(format: "CGContextSetMiterLimit(context, %.2f)", miterLimit))
    }
    
    func getUnifyValue(params:NSDictionary, key:String) -> AnyObject?
    {
        let data = params.valueForKey(key)
        if let data = data where data is NSNull
        {
            return nil
        }
        
        return data
    }
    
    func strokePathWithGradientStyle(context:CGContext?, path:CGMutablePath)
    {
        let gradientPath = CGPathCreateCopyByStrokingPath(path, nil, lineWidth, lineCap, lineJoin, miterLimit)
        CGContextAddPath(context, gradientPath)
        print(String(format: "gradientPath = CGPathCreateCopyByStrokingPath(path, nil, %.2f, CGLineCap(rawValue:%d)!, CGLineJoin(rawValue:%d)!, %.2f)", lineWidth, lineCap.rawValue, lineJoin.rawValue, miterLimit))
        print("CGContextAddPath(context, gradientPath)")
        CGContextClip(context)
        print("CGContextClip(context)")
        
        fillContextGradientStyle(context, params: style)
    }
    
    func fillContextGradientStyle(context:CGContext?, params:NSDictionary)
    {
        let style = getGradientStyle(params)
        let matrix = style.matrix
        
        let angle = atan2(matrix.b, matrix.a)
        let scaleX = matrix.a / cos(angle)
        let scaleY = matrix.d / cos(angle)
        
        let width = scaleX * 1638.4, height = scaleY * 1638.4
        
        if style.type == "radial"
        {
            if width != height
            {
                //TODO: 椭圆情况做变形处理
            }
            
            let endRadius = max(width / 2, height / 2);
            let startCenter = CGPointMake(width / 2 * cos(angle) * style.focalPointRatio + matrix.tx,
                                         height / 2 * sin(angle) * style.focalPointRatio + matrix.ty)
            let endCenter = CGPointMake(matrix.tx, matrix.ty)
            
            CGContextDrawRadialGradient(context, style.gradient, startCenter, 0, endCenter, endRadius, CGGradientDrawingOptions.DrawsAfterEndLocation)
            print(String(format: "CGContextDrawRadialGradient(context, gradient, CGPointMake(%.2f, %.2f), 0, CGPointMake(%.2f, %.2f), %.2f, CGGradientDrawingOptions.DrawsAfterEndLocation)",
                startCenter.x, startCenter.y, endCenter.x, endCenter.y, endRadius))
        }
        else
        {
            let sp = CGPointMake(-819.2 * scaleX, 0)
            let startPoint = CGPointMake(sp.x * cos(angle) - sp.y * sin(angle) + matrix.tx,
                                         sp.x * sin(angle) + sp.y * cos(angle) + matrix.ty)
            let ep = CGPointMake( 819.2 * scaleX, 0)
            let endPoint = CGPointMake(ep.x * cos(angle) - ep.y * sin(angle) + matrix.tx,
                                       ep.x * sin(angle) + ep.y * cos(angle) + matrix.ty)
            
            let options:CGGradientDrawingOptions = [CGGradientDrawingOptions.DrawsBeforeStartLocation, CGGradientDrawingOptions.DrawsAfterEndLocation]
            CGContextDrawLinearGradient(context, style.gradient, startPoint, endPoint, options)
            print(String(format: "CGContextDrawLinearGradient(context, gradient, CGPointMake(%.2f, %.2f), CGPointMake(%.2f, %.2f), CGGradientDrawingOptions(rawValue: %d))",
                startPoint.x, startPoint.y, endPoint.x, endPoint.y, options.rawValue))
        }
    }
}
