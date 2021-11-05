
import UIKit
import Alamofire

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
  }

}
