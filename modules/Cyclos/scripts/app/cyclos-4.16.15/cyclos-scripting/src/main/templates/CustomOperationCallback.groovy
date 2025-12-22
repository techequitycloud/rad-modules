import org.cyclos.entities.banking.Transfer
import org.cyclos.entities.contentmanagement.MenuItem
import org.cyclos.entities.marketplace.BasicAd
import org.cyclos.entities.system.CustomOperation
import org.cyclos.entities.system.ExportFormat
import org.cyclos.entities.system.ExternalRedirectExecution
import org.cyclos.entities.users.Contact
import org.cyclos.entities.users.ContactInfo
import org.cyclos.entities.users.CustomOperationBulkAction
import org.cyclos.entities.users.Record
import org.cyclos.entities.users.User
import org.cyclos.model.utils.FileInfo
import org.cyclos.model.utils.RequestInfo
import org.cyclos.server.utils.ObjectParameterStorage

BasicAd ad = binding.ad
CustomOperationBulkAction bulkAction = binding.bulkAction
Contact contact = binding.contact
ContactInfo contactInfo = binding.contactInfo
Integer currentPage = binding.currentPage
CustomOperation customOperation = binding.customOperation
ExternalRedirectExecution execution = binding.execution
ExportFormat exportFormat = binding.exportFormat
Map<String, Object> formParameters = binding.formParameters
FileInfo inputFile = binding.inputFile
MenuItem menuItem = binding.menuItem
Integer pageSize = binding.pageSize
Record record = binding.record
RequestInfo request = binding.request
String returnUrl = binding.returnUrl
String scannedQrCode = binding.scannedQrCode
Boolean skipTotalCount = binding.skipTotalCount
ObjectParameterStorage storage = binding.storage
Transfer transfer = binding.transfer
User user = binding.user

throw new UnsupportedOperationException('Script not implemented')