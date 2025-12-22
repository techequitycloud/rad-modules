import org.cyclos.model.system.extensionpoints.ExtensionPointEvent
import org.cyclos.entities.system.ExtensionPoint
 
Map<String, Object> context = binding.context
ExtensionPointEvent event = binding.event
ExtensionPoint extensionPoint = binding.extensionPoint
 
// User
/*
import org.cyclos.entities.users.Group
import org.cyclos.entities.users.User
import org.cyclos.model.users.users.UserStatus

String comments = binding.comments
User currentCopy = binding.currentCopy
Group newGroup = binding.newGroup
UserStatus newStatus = binding.newStatus
Group oldGroup = binding.oldGroup
UserStatus oldStatus = binding.oldStatus
User user = binding.user
*/

// Operator
/*
import org.cyclos.entities.users.Operator
import org.cyclos.entities.users.OperatorGroup
import org.cyclos.model.users.users.UserStatus

String comments = binding.comments
Operator currentCopy = binding.currentCopy
OperatorGroup newGroup = binding.newGroup
UserStatus newStatus = binding.newStatus
OperatorGroup oldGroup = binding.oldGroup
UserStatus oldStatus = binding.oldStatus
Operator operator = binding.operator
*/

// UserAddress
/*
import org.cyclos.entities.users.UserAddress

UserAddress address = binding.address
UserAddress currentCopy = binding.currentCopy
*/

// Phone
/*
import org.cyclos.entities.users.Phone

Phone currentCopy = binding.currentCopy
Phone phone = binding.phone
*/

// Record
/*
import org.cyclos.entities.users.Record

Record currentCopy = binding.currentCopy
Record record = binding.record
*/

// Ad
/*
import org.cyclos.entities.marketplace.BasicAd

BasicAd ad = binding.ad
BasicAd currentCopy = binding.currentCopy
*/

// Order
/*
import org.cyclos.entities.marketplace.Order
import org.cyclos.model.marketplace.webshoporders.OrderStatus

OrderStatus newStatus = binding.newStatus
OrderStatus oldStatus = binding.oldStatus
Order order = binding.order
Boolean wasPendingByAdmin = binding.wasPendingByAdmin
*/

// Transaction
/*
import org.cyclos.entities.banking.Account
import org.cyclos.entities.banking.AuthorizationLevel
import org.cyclos.entities.banking.Installment
import org.cyclos.entities.banking.PaymentTransferType
import org.cyclos.entities.banking.Transaction
import org.cyclos.impl.banking.LocateAccountOwnerResult
import org.cyclos.model.banking.accounts.AccountOwner
import org.cyclos.model.banking.accounts.InternalAccountOwner
import org.cyclos.model.banking.transactions.PerformTransactionDTO
import org.cyclos.model.banking.transactions.TransactionAuthorizationType
import org.cyclos.model.banking.transactions.TransactionPreviewVO
import org.cyclos.model.banking.transactions.TransactionStatus

AuthorizationLevel authorizationLevel = binding.authorizationLevel
TransactionAuthorizationType authorizationType = binding.authorizationType
Account fromAccount = binding.fromAccount
InternalAccountOwner fromOwner = binding.fromOwner
LocateAccountOwnerResult fromOwnerResult = binding.fromOwnerResult
Installment installment = binding.installment
TransactionStatus newtatus = binding.newtatus
TransactionStatus oldStatus = binding.oldStatus
PaymentTransferType paymentType = binding.paymentType
PerformTransactionDTO performTransaction = binding.performTransaction
TransactionPreviewVO preview = binding.preview
Account toAccount = binding.toAccount
AccountOwner toOwner = binding.toOwner
LocateAccountOwnerResult toOwnerResult = binding.toOwnerResult
Transaction transaction = binding.transaction
*/

// Transfer
/*
import org.cyclos.entities.banking.ChargebackTransfer
import org.cyclos.entities.banking.Transfer
import org.cyclos.entities.banking.TransferStatus
import org.cyclos.entities.banking.TransferStatusFlow

ChargebackTransfer chargeback = binding.chargeback
String comments = binding.comments
TransferStatusFlow flow = binding.flow
TransferStatus newtatus = binding.newtatus
TransferStatus oldStatus = binding.oldStatus
Transfer transfer = binding.transfer
*/

// Authorization
/*
import org.cyclos.entities.banking.AuthorizationLevel
import org.cyclos.entities.banking.BasePayment

String comment = binding.comment
AuthorizationLevel currentLevel = binding.currentLevel
AuthorizationLevel nextLevel = binding.nextLevel
BasePayment transaction = binding.transaction
*/

// Voucher
/*
import org.cyclos.entities.banking.Voucher
import org.cyclos.entities.users.User
import org.cyclos.model.banking.vouchers.VoucherStatus

BigDecimal amount = binding.amount
VoucherStatus previousStatus = binding.previousStatus
User user = binding.user
Voucher voucher = binding.voucher
*/

// Agreement
/*
import org.cyclos.entities.access.Agreement
import org.cyclos.entities.users.User

Agreement agreement = binding.agreement
User user = binding.user
*/

// Import
/*
import org.cyclos.entities.SimpleEntity
import org.cyclos.entities.system.ImportedFile
import org.cyclos.entities.system.ImportedLine
import org.cyclos.model.system.imports.ImportedFileStatus

SimpleEntity entity = binding.entity
Exception error = binding.error
ImportedFile importedFile = binding.importedFile
ImportedLine line = binding.line
ImportedFileStatus newStatus = binding.newStatus
ImportedFileStatus oldStatus = binding.oldStatus
*/

throw new UnsupportedOperationException('Script not implemented')