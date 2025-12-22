import org.cyclos.entities.banking.PaymentTransferType
import org.cyclos.entities.banking.Transfer
import org.cyclos.entities.banking.Voucher
import org.cyclos.entities.banking.VoucherType
import org.cyclos.entities.contentmanagement.DynamicDocument
import org.cyclos.entities.contentmanagement.MenuItem
import org.cyclos.entities.marketplace.BasicAd
import org.cyclos.entities.system.CustomField
import org.cyclos.entities.system.CustomFieldPossibleValue
import org.cyclos.entities.system.CustomFieldPossibleValueCategory
import org.cyclos.entities.system.CustomOperation
import org.cyclos.entities.system.CustomWizard
import org.cyclos.entities.system.CustomWizardExecution
import org.cyclos.entities.system.FormFieldsWizardStep
import org.cyclos.entities.users.Contact
import org.cyclos.entities.users.ContactInfo
import org.cyclos.entities.users.Operator
import org.cyclos.entities.users.Record
import org.cyclos.entities.users.User
import org.cyclos.impl.banking.LocateAccountOwnerResult
import org.cyclos.impl.system.CustomWizardExecutionStorage
import org.cyclos.model.banking.accounts.AccountOwner
import org.cyclos.model.banking.accounts.InternalAccountOwner
import org.cyclos.model.banking.vouchers.VoucherCreationType

BasicAd ad = binding.ad
Contact contact = binding.contact
ContactInfo contactInfo = binding.contactInfo
CustomOperation customOperation = binding.customOperation
DynamicDocument document = binding.document
CustomWizardExecution execution = binding.execution
CustomField field = binding.field
Map<String, Object> formParameters = binding.formParameters
InternalAccountOwner fromOwner = binding.fromOwner
LocateAccountOwnerResult fromOwnerResult = binding.fromOwnerResult
MenuItem menuItem = binding.menuItem
Operator operator = binding.operator
PaymentTransferType paymentType = binding.paymentType
Record record = binding.record
FormFieldsWizardStep step = binding.step
CustomWizardExecutionStorage storage = binding.storage
AccountOwner toOwner = binding.toOwner
LocateAccountOwnerResult toOwnerResult = binding.toOwnerResult
Transfer transfer = binding.transfer
User user = binding.user
Voucher voucher = binding.voucher
VoucherCreationType voucherCreationType = binding.voucherCreationType
VoucherType voucherType = binding.voucherType
CustomWizard wizard = binding.wizard

throw new UnsupportedOperationException('Script not implemented')