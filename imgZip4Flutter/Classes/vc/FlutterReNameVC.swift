//
//  ViewController.swift
//  unZipImg
//
//  Created by dfpo on 2021/1/24.
//

import Cocoa
import ZIPFoundation
import xUtils
import xViews
private func getLibBundle() -> Bundle? {
    let fb = Bundle(for: FlutterReNameVC.self)
    guard let path = fb.path(forResource: "imgZip4Flutter", ofType: "bundle") else {
        return nil
    }
    return Bundle(path: path)
    
}
private func getImg(_ imgName: String?) -> NSImage? {
    guard let imgName = imgName else {
        return nil
    }
    return getLibBundle()?.image(forResource: imgName)
}
public class FlutterReNameVC: NSViewController {
    @IBOutlet var m_textView: NSTextView!

    public static func vc() -> FlutterReNameVC {
        return FlutterReNameVC(nibName: "FlutterReNameVC", bundle: getLibBundle())
    }
    /// 输入框
    @IBOutlet private weak var m_textField: NSSearchField!
    private var imgNames = [String]()
    @IBOutlet private weak var m_tableView: NSTableView!
    /// 历史目标文件夹
    private lazy var m_historyDestinationFolderPaths = [String]()
    /// zip包是单张图片还是多张图片，单张图片可选重命名zip内包含3张图片，多张图片不重命名
    @IBOutlet private weak var imgCntSeg: NSSegmentedControl!
    @IBOutlet private weak var m_listBox: NSComboBox!
    public override func viewDidLoad() {
        super.viewDidLoad()
        title = "蓝湖图片zip 重命名 for Flutter"
        
        // 回显历史的重命名
        imgNames.append(contentsOf: xUtils.getStrsFromUserDefaults(key: "zip_img_names"))
        m_tableView.reloadData()
        
        // 给table的cell添加右键菜单
        let menu = NSMenu()
        menu.delegate = self
        m_tableView.menu = menu
        
        // 下拉框
        m_listBox.dataSource = self
        m_listBox.delegate  = self
        m_historyDestinationFolderPaths.append(contentsOf: xUtils.getStrsFromUserDefaults(key: "spFolderPath"))
        m_listBox.reloadData()
        if !m_historyDestinationFolderPaths.isEmpty {
            m_listBox.selectItem(at: 0)
        }
        
        // 不要搜索图标
        (m_textField.cell as? NSSearchFieldCell)?.searchButtonCell = nil
    }
    
    
    func unZipAtURL(_ zipFileURL: URL){
        guard !m_listBox.stringValue.isEmpty else {
            xUtils.showAlter(msg: "得先指定flutter的图片文件夹")
            return
        }
        let has2x = xUtils.isFolderExists("\(m_listBox.stringValue)/2.0x")
        let has3x = xUtils.isFolderExists("\(m_listBox.stringValue)/3.0x")
        
        if has2x && has3x {
            zipToDefaultFolder(zipFileURL)
        }
    }
    func zipToDefaultFolder(_ zipFileURL: URL){
        let fm = FileManager()
        /// flutter存放图片的文件夹，有1x图片文件，2x文件夹，3x文件夹
        let flutterImgFolderPath = m_listBox.stringValue
        let flutterImgFolderURL = URL(fileURLWithPath: flutterImgFolderPath)
        
        let unzipTempFolderPath =  zipFileURL.pathComponents.dropLast().joined(separator: "/").dropFirst().appending("/unzipDataTemp")
        let unzipTempFolderURL = URL(fileURLWithPath: unzipTempFolderPath)
        xUtils.removeFolderAtPath(unzipTempFolderPath)
        xUtils.createFolder(unzipTempFolderPath)
        let isSingImgZip = imgCntSeg.selectedSegment == 1
        let imgNewName = m_textField.stringValue
        do {
            // 解压切换zip到 下载下的unzipData文件夹
            try fm.unzipItem(at: zipFileURL, to: unzipTempFolderURL)
            let secStr = "@2x.png"
            let thrStr = "@3x.png"
            // 只遍历当前文件夹下的文件，不再深入子文件夹
            if let files = try? fm.contentsOfDirectory(atPath: unzipTempFolderURL.path).filter({$0.hasSuffix(".png")}), (!isSingImgZip || (isSingImgZip && files.count == 3)) {
                
                for currentFile in files {
                    // 要移动的文件位置
                    let currentFileURL = unzipTempFolderURL.appendingPathComponent(currentFile)
                    
                    var destFileName = currentFile.replacingOccurrences(of: "@2x", with: "").replacingOccurrences(of: "@3x", with: "")
                    if isSingImgZip {
                        // 单张图片可重命名
                        destFileName  = imgNewName.isEmpty ? destFileName : "\(imgNewName).png"
                    }
                    
                    
                    // 默认移动到指定文件夹
                    var destFolderURL = flutterImgFolderURL
                    var folder23 = "1.0x"
                    if currentFile.hasSuffix(secStr) || currentFile.hasSuffix(thrStr) {
                        folder23  = currentFile.contains("@2x") ? "2.0x" : "3.0x"
                        destFolderURL = flutterImgFolderURL.appendingPathComponent(folder23, isDirectory: true)
                    }
                    
                    
                    if let oldFiles = try? fm.contentsOfDirectory(atPath: destFolderURL.path), !oldFiles.isEmpty {
                        if oldFiles.contains(destFileName) {
                            output("\(folder23)文件夹，已存在图片\(destFileName)")

                            continue
                        } else {
                            // 被移动到目标的文件位置
                            let destFileURL = destFolderURL.appendingPathComponent(destFileName)
                            do {
                                try fm.moveItem(at: currentFileURL, to: destFileURL)
                            } catch {
                                output(error.localizedDescription)
                            }
                        }
                    }
                }
                saveImgName(imgNewName)
            } else {
                output("zip包内的图片数量大于3,需要切换到多张选项")
return
            }
            
            
            // 删除zip文件
            delZip(zipFileURL, isNeedDelZip: false)
        } catch {
            output(error.localizedDescription)
        }
    }
    private func saveImgName(_ imgNewName: String) {
        if !imgNewName.isEmpty {
            let newNames = xUtils.saveStrToStrArr(key: "zip_img_names" , saveStr: imgNewName )
            if !newNames.isEmpty {
                imgNames.removeAll()
                imgNames.append(contentsOf: newNames)
                m_tableView.reloadData()
            }
        }
    }
    private func delZip(_ zipFileURL:URL?, isNeedDelZip: Bool?) {
        if let zipFileURL = zipFileURL, let isNeedDelZip = isNeedDelZip, isNeedDelZip {
            do {
                try FileManager.default.removeItem(atPath: zipFileURL.path)
            } catch {
                output(error.localizedDescription)
            }
        }
    }
    
    
    @IBAction func doubleAction(_ sender: NSTableView) {
        let idx = sender.selectedRow
        if idx >= 0, idx < imgNames.count {
            m_textField.stringValue = imgNames[idx]
        }
        
    }
    // 选择flutter放图片的文件夹
    @IBAction func chooseFolder(_ sender: NSButton) {
        
        xUtils.chooseFolder(for: view.window) { folderPath in
            
            let has2x = xUtils.isFolderExists("\(folderPath)/2.0x")
            let has3x = xUtils.isFolderExists("\(folderPath)/3.0x")
            
            if has2x && has3x {
                
                let folderPaths = xUtils.saveStrToStrArr(key: "spFolderPath", saveStr: folderPath)
                self.m_historyDestinationFolderPaths.removeAll()
                self.m_historyDestinationFolderPaths.append(contentsOf: folderPaths)
                self.m_listBox.reloadData()
                if let desIdx = self.m_historyDestinationFolderPaths.firstIndex(of: folderPath) {
                    self.m_listBox.selectItem(at: desIdx)
                }
               
            } else {
                xUtils.showAlter(msg: "文件夹下，应该有2.0x和3.0x文件夹")
            }
        }
    }
    
    @IBAction func clickClearBtn(_ sender: NSButton) {
        m_listBox.stringValue = ""
        UserDefaults.standard.set(nil, forKey: "spFolderPath")
        m_historyDestinationFolderPaths.removeAll()
        m_listBox.reloadData()
    }
    private func output(_ str: String?) {
        guard let str = str, !str.isEmpty else {
            return
        }
        m_textView.string = m_textView.string.appending("\n").appending(str)
        let range = NSRange(location:m_textView.string.count,length:0)
        m_textView.scrollRangeToVisible(range)
    }
}
extension FlutterReNameVC: FileDragDelegate {
   public func didFinishDrag(_ URLs: [URL]) {
        
        let fileURL = URLs[0]
        let ext = fileURL.pathExtension
        switch ext {
        case "zip":
            output(fileURL.absoluteString)
            unZipAtURL(fileURL)
        default:
            print(ext)
        }
    }
}
// MARK: - NSTableViewDataSource
extension FlutterReNameVC: NSTableViewDataSource {
    public func numberOfRows(in tableView: NSTableView) -> Int {
        return imgNames.count
    }
}
// MARK: - NSTableViewDelegate
extension FlutterReNameVC: NSTableViewDelegate {
    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        let imgName = imgNames[row]
        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier("his"), owner: self) as? NSTableCellView {
            cell.textField?.stringValue = imgName
            return cell
        }
        return nil
    }
}
// MARK: - NSMenuDelegate
extension FlutterReNameVC: NSMenuDelegate {
    public func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        // 在这里动态添加 menu item
        menu.addItem(NSMenuItem(title: "删除", action: #selector(handleDeleteClickedRow), keyEquivalent: ""))
    }
    @objc func handleDeleteClickedRow(){
        let idx = m_tableView.selectedRow
        guard idx >= 0,
              m_tableView.clickedColumn >= 0,
              let row: NSTableRowView = m_tableView.rowView(atRow: idx, makeIfNecessary: false),
              let cellView = row.view(atColumn: m_tableView.clickedColumn) as? NSTableCellView  else {
            return
        }
        
        //                刷新
        imgNames.remove(at: idx)
        m_tableView.reloadData()
        //                偏好同步
        UserDefaults.standard.set(imgNames, forKey: "zip_img_names")
        
    }
}
extension FlutterReNameVC: NSComboBoxDataSource {
    public func comboBox(_ aComboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
        guard index < m_historyDestinationFolderPaths.count else {
            return nil
        }
        return m_historyDestinationFolderPaths[index]
    }
    
    public func numberOfItems(in aComboBox: NSComboBox) -> Int {
        return m_historyDestinationFolderPaths.count
    }
}
extension FlutterReNameVC: NSComboBoxDelegate {
    public func comboBoxSelectionDidChange(_ notification: Notification) {
        if let comboBox = notification.object as? NSComboBox, comboBox === m_listBox {
            guard comboBox.indexOfSelectedItem < m_historyDestinationFolderPaths.count else { return }
            
        }
    }
}
extension FlutterReNameVC: NSSplitViewDelegate {
    public func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        return proposedMinimumPosition+90
    }
    public func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        return proposedMaximumPosition-90
    }
}
