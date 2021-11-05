
import UIKit
import Alamofire
import MondrianLayout

class ViewController: UIViewController {

  override func viewDidLoad() {
    super.viewDidLoad()
    // Do any additional setup after loading the view.
    view.backgroundColor = .white

    print(Alamofire.Session.self)

    do {
      let session = Session()
      print(session)
    }

    view.mondrian.buildSubviews {
      VStackBlock {
        { () -> UILabel in
          let label = UILabel()
          label.text = "Hello"
          return label
        }()
      }
    }
  }

}
