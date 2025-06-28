//
//  SliceListViewController.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 6/28/25.
//
import UIKit

final class SliceListViewController: UIViewController {
    private enum Section { case main }
    private let track: AudioTrack
    private let arrangement: Arrangement
    private var slices: [Slice] = []

    private var tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var dataSource: UITableViewDiffableDataSource<Section, Slice>!

    init(track: AudioTrack, arrangement: Arrangement) {
        self.track = track;
        self.arrangement = arrangement;
        super.init(nibName:nil,bundle:nil)
    }
    required init?(coder:NSCoder){ fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad();
        title = arrangement.name;
        view.backgroundColor = .systemBackground
        configureTable();
        configureDataSource();
        loadSlices()
        
        navigationItem.rightBarButtonItem=UIBarButtonItem(systemItem:.play, primaryAction:UIAction{[weak self]_ in self?.playAll()})
        
    }

    private func configureTable() {
        view.addSubview(tableView); tableView.translatesAutoresizingMaskIntoConstraints=false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo:view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo:view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo:view.bottomAnchor)
        ])
    }
    private func configureDataSource() {
        dataSource = UITableViewDiffableDataSource<Section, Slice>(tableView: tableView) { tv, _, slice in
            let cell = tv.dequeueReusableCell(withIdentifier:"SliceCell") ?? UITableViewCell(style:.subtitle, reuseIdentifier:"SliceCell")
            let idx = tv.indexPath(for: cell)?.row ?? 0
            cell.textLabel?.text = "Slice \(idx + 1): " + (slice.transcript ?? "<noise>")
            let time = String(format: "%.2f–%.2f s", slice.start, slice.end)
            cell.detailTextLabel?.text = time
            cell.selectionStyle = .none
            if slice.category == .noise { cell.textLabel?.textColor = .secondaryLabel }
            return cell
        }
    }
    private func loadSlices() {
        slices = DataManager.shared.mockSlices()
        var snap = NSDiffableDataSourceSnapshot<Section, Slice>()
        snap.appendSections([.main]); snap.appendItems(slices)
        dataSource.apply(snap, animatingDifferences: true)
    }
    
    

    private func playAll(){
        let learnable=slices.filter{ $0.category == .learnable};
        let vc=StudyPlayerViewController(track:track, slices:learnable);
        navigationController?.pushViewController(vc, animated:true)
    }
    
}


final class SliceListViewController2:UIViewController{
    enum Section{case main};
    private let track:AudioTrack;
    private let arrangement:Arrangement;
    private var slices:[Slice]=[]
    
    private let tableView=UITableView(frame:.zero, style:.insetGrouped)
    private var ds:UITableViewDiffableDataSource<Section,Slice>!
    
    
    init(track:AudioTrack, arrangement:Arrangement){
        self.track=track;
        self.arrangement=arrangement;
        super.init(nibName:nil,bundle:nil) }
    
    required init?(coder:NSCoder){fatalError()}
    
    
    override func viewDidLoad(){
        
        super.viewDidLoad();
        title = arrangement.name;
        view.backgroundColor = .systemBackground;
        
        configureTable();
        configureDataSource();
        load();
        

        
    }
    
    private func configureTable(){ view.addSubview(tableView); tableView.translatesAutoresizingMaskIntoConstraints=false; NSLayoutConstraint.activate([
        tableView.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor), tableView.leadingAnchor.constraint(equalTo:view.leadingAnchor), tableView.trailingAnchor.constraint(equalTo:view.trailingAnchor), tableView.bottomAnchor.constraint(equalTo:view.bottomAnchor)])
    }
    
    private func configureDataSource(){ ds=UITableViewDiffableDataSource<Section,Slice>(tableView:tableView) { tv,_,s in
            let c=tv.dequeueReusableCell(withIdentifier:"SliceCell") ?? UITableViewCell(style:.subtitle, reuseIdentifier:"SliceCell");
        
            let idx=tv.indexPath(for:c)?.row ?? 0;
            c.textLabel?.text="Slice \(idx+1): "+(s.transcript ?? "<noise>");
            
            c.detailTextLabel?.text=String(format:"%.2f–%.2f s",s.start,s.end);
            c.selectionStyle = .none;
            if s.category == .noise{ c.textLabel?.textColor = .secondaryLabel };
            return c
        }
    }
    private func load(){
        slices  =   DataManager.shared.mockSlices();
        var snap=NSDiffableDataSourceSnapshot<Section,Slice>();
        snap.appendSections([.main]);
        snap.appendItems(slices);
        ds.apply(snap, animatingDifferences:true) }
    

    private func playAll(){
        let learnable=slices.filter{ $0.category == .learnable};
        let vc=StudyPlayerViewController(track:track, slices:learnable);
        navigationController?.pushViewController(vc, animated:true)
    }
}
