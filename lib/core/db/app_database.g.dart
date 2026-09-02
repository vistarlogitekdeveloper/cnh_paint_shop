// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $OutboxItemsTable extends OutboxItems
    with TableInfo<$OutboxItemsTable, OutboxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _clientUuidMeta = const VerificationMeta(
    'clientUuid',
  );
  @override
  late final GeneratedColumn<String> clientUuid = GeneratedColumn<String>(
    'client_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  @override
  late final GeneratedColumnWithTypeConverter<OutboxKind, int> kind =
      GeneratedColumn<int>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<OutboxKind>($OutboxItemsTable.$converterkind);
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  late final GeneratedColumnWithTypeConverter<OutboxState, int> state =
      GeneratedColumn<int>(
        'state',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: Constant(OutboxState.pending.index),
      ).withConverter<OutboxState>($OutboxItemsTable.$converterstate);
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorCodeMeta = const VerificationMeta(
    'errorCode',
  );
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
    'error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serverStateMeta = const VerificationMeta(
    'serverState',
  );
  @override
  late final GeneratedColumn<String> serverState = GeneratedColumn<String>(
    'server_state',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _queuedAtMeta = const VerificationMeta(
    'queuedAt',
  );
  @override
  late final GeneratedColumn<DateTime> queuedAt = GeneratedColumn<DateTime>(
    'queued_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nextAttemptAtMeta = const VerificationMeta(
    'nextAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextAttemptAt =
      GeneratedColumn<DateTime>(
        'next_attempt_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    clientUuid,
    kind,
    payload,
    summary,
    state,
    attempts,
    lastError,
    errorCode,
    serverState,
    queuedAt,
    updatedAt,
    nextAttemptAt,
    userId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('client_uuid')) {
      context.handle(
        _clientUuidMeta,
        clientUuid.isAcceptableOrUnknown(data['client_uuid']!, _clientUuidMeta),
      );
    } else if (isInserting) {
      context.missing(_clientUuidMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('error_code')) {
      context.handle(
        _errorCodeMeta,
        errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta),
      );
    }
    if (data.containsKey('server_state')) {
      context.handle(
        _serverStateMeta,
        serverState.isAcceptableOrUnknown(
          data['server_state']!,
          _serverStateMeta,
        ),
      );
    }
    if (data.containsKey('queued_at')) {
      context.handle(
        _queuedAtMeta,
        queuedAt.isAcceptableOrUnknown(data['queued_at']!, _queuedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_queuedAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
        _nextAttemptAtMeta,
        nextAttemptAt.isAcceptableOrUnknown(
          data['next_attempt_at']!,
          _nextAttemptAtMeta,
        ),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      clientUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_uuid'],
      )!,
      kind: $OutboxItemsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}kind'],
        )!,
      ),
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      )!,
      state: $OutboxItemsTable.$converterstate.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}state'],
        )!,
      ),
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      errorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_code'],
      ),
      serverState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_state'],
      ),
      queuedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}queued_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_attempt_at'],
      ),
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
    );
  }

  @override
  $OutboxItemsTable createAlias(String alias) {
    return $OutboxItemsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<OutboxKind, int, int> $converterkind =
      const EnumIndexConverter<OutboxKind>(OutboxKind.values);
  static JsonTypeConverter2<OutboxState, int, int> $converterstate =
      const EnumIndexConverter<OutboxState>(OutboxState.values);
}

class OutboxRow extends DataClass implements Insertable<OutboxRow> {
  final int id;

  /// Generated on THIS device before the row is first written. The server's
  /// unique index on it is the idempotency guarantee.
  final String clientUuid;
  final OutboxKind kind;

  /// The request body, as JSON.
  final String payload;

  /// A short human description for the pending-queue screen ("LEVER ×60"), so
  /// the operator can see WHAT is waiting without decoding JSON.
  final String summary;
  final OutboxState state;
  final int attempts;
  final String? lastError;
  final String? errorCode;

  /// The server's view when it reported a conflict, so the screen can explain
  /// exactly what changed underneath the operator.
  final String? serverState;
  final DateTime queuedAt;
  final DateTime updatedAt;

  /// Backoff gate: not retried before this instant.
  final DateTime? nextAttemptAt;

  /// Which user queued it. A shared tablet can be handed over mid-shift, and an
  /// entry must stay attributed to whoever actually made it.
  final String? userId;
  const OutboxRow({
    required this.id,
    required this.clientUuid,
    required this.kind,
    required this.payload,
    required this.summary,
    required this.state,
    required this.attempts,
    this.lastError,
    this.errorCode,
    this.serverState,
    required this.queuedAt,
    required this.updatedAt,
    this.nextAttemptAt,
    this.userId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['client_uuid'] = Variable<String>(clientUuid);
    {
      map['kind'] = Variable<int>($OutboxItemsTable.$converterkind.toSql(kind));
    }
    map['payload'] = Variable<String>(payload);
    map['summary'] = Variable<String>(summary);
    {
      map['state'] = Variable<int>(
        $OutboxItemsTable.$converterstate.toSql(state),
      );
    }
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    if (!nullToAbsent || serverState != null) {
      map['server_state'] = Variable<String>(serverState);
    }
    map['queued_at'] = Variable<DateTime>(queuedAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || nextAttemptAt != null) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt);
    }
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    return map;
  }

  OutboxItemsCompanion toCompanion(bool nullToAbsent) {
    return OutboxItemsCompanion(
      id: Value(id),
      clientUuid: Value(clientUuid),
      kind: Value(kind),
      payload: Value(payload),
      summary: Value(summary),
      state: Value(state),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
      serverState: serverState == null && nullToAbsent
          ? const Value.absent()
          : Value(serverState),
      queuedAt: Value(queuedAt),
      updatedAt: Value(updatedAt),
      nextAttemptAt: nextAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextAttemptAt),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
    );
  }

  factory OutboxRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxRow(
      id: serializer.fromJson<int>(json['id']),
      clientUuid: serializer.fromJson<String>(json['clientUuid']),
      kind: $OutboxItemsTable.$converterkind.fromJson(
        serializer.fromJson<int>(json['kind']),
      ),
      payload: serializer.fromJson<String>(json['payload']),
      summary: serializer.fromJson<String>(json['summary']),
      state: $OutboxItemsTable.$converterstate.fromJson(
        serializer.fromJson<int>(json['state']),
      ),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
      serverState: serializer.fromJson<String?>(json['serverState']),
      queuedAt: serializer.fromJson<DateTime>(json['queuedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      nextAttemptAt: serializer.fromJson<DateTime?>(json['nextAttemptAt']),
      userId: serializer.fromJson<String?>(json['userId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'clientUuid': serializer.toJson<String>(clientUuid),
      'kind': serializer.toJson<int>(
        $OutboxItemsTable.$converterkind.toJson(kind),
      ),
      'payload': serializer.toJson<String>(payload),
      'summary': serializer.toJson<String>(summary),
      'state': serializer.toJson<int>(
        $OutboxItemsTable.$converterstate.toJson(state),
      ),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
      'errorCode': serializer.toJson<String?>(errorCode),
      'serverState': serializer.toJson<String?>(serverState),
      'queuedAt': serializer.toJson<DateTime>(queuedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'nextAttemptAt': serializer.toJson<DateTime?>(nextAttemptAt),
      'userId': serializer.toJson<String?>(userId),
    };
  }

  OutboxRow copyWith({
    int? id,
    String? clientUuid,
    OutboxKind? kind,
    String? payload,
    String? summary,
    OutboxState? state,
    int? attempts,
    Value<String?> lastError = const Value.absent(),
    Value<String?> errorCode = const Value.absent(),
    Value<String?> serverState = const Value.absent(),
    DateTime? queuedAt,
    DateTime? updatedAt,
    Value<DateTime?> nextAttemptAt = const Value.absent(),
    Value<String?> userId = const Value.absent(),
  }) => OutboxRow(
    id: id ?? this.id,
    clientUuid: clientUuid ?? this.clientUuid,
    kind: kind ?? this.kind,
    payload: payload ?? this.payload,
    summary: summary ?? this.summary,
    state: state ?? this.state,
    attempts: attempts ?? this.attempts,
    lastError: lastError.present ? lastError.value : this.lastError,
    errorCode: errorCode.present ? errorCode.value : this.errorCode,
    serverState: serverState.present ? serverState.value : this.serverState,
    queuedAt: queuedAt ?? this.queuedAt,
    updatedAt: updatedAt ?? this.updatedAt,
    nextAttemptAt: nextAttemptAt.present
        ? nextAttemptAt.value
        : this.nextAttemptAt,
    userId: userId.present ? userId.value : this.userId,
  );
  OutboxRow copyWithCompanion(OutboxItemsCompanion data) {
    return OutboxRow(
      id: data.id.present ? data.id.value : this.id,
      clientUuid: data.clientUuid.present
          ? data.clientUuid.value
          : this.clientUuid,
      kind: data.kind.present ? data.kind.value : this.kind,
      payload: data.payload.present ? data.payload.value : this.payload,
      summary: data.summary.present ? data.summary.value : this.summary,
      state: data.state.present ? data.state.value : this.state,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
      serverState: data.serverState.present
          ? data.serverState.value
          : this.serverState,
      queuedAt: data.queuedAt.present ? data.queuedAt.value : this.queuedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      userId: data.userId.present ? data.userId.value : this.userId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxRow(')
          ..write('id: $id, ')
          ..write('clientUuid: $clientUuid, ')
          ..write('kind: $kind, ')
          ..write('payload: $payload, ')
          ..write('summary: $summary, ')
          ..write('state: $state, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('errorCode: $errorCode, ')
          ..write('serverState: $serverState, ')
          ..write('queuedAt: $queuedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('userId: $userId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    clientUuid,
    kind,
    payload,
    summary,
    state,
    attempts,
    lastError,
    errorCode,
    serverState,
    queuedAt,
    updatedAt,
    nextAttemptAt,
    userId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxRow &&
          other.id == this.id &&
          other.clientUuid == this.clientUuid &&
          other.kind == this.kind &&
          other.payload == this.payload &&
          other.summary == this.summary &&
          other.state == this.state &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError &&
          other.errorCode == this.errorCode &&
          other.serverState == this.serverState &&
          other.queuedAt == this.queuedAt &&
          other.updatedAt == this.updatedAt &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.userId == this.userId);
}

class OutboxItemsCompanion extends UpdateCompanion<OutboxRow> {
  final Value<int> id;
  final Value<String> clientUuid;
  final Value<OutboxKind> kind;
  final Value<String> payload;
  final Value<String> summary;
  final Value<OutboxState> state;
  final Value<int> attempts;
  final Value<String?> lastError;
  final Value<String?> errorCode;
  final Value<String?> serverState;
  final Value<DateTime> queuedAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> nextAttemptAt;
  final Value<String?> userId;
  const OutboxItemsCompanion({
    this.id = const Value.absent(),
    this.clientUuid = const Value.absent(),
    this.kind = const Value.absent(),
    this.payload = const Value.absent(),
    this.summary = const Value.absent(),
    this.state = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.serverState = const Value.absent(),
    this.queuedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.userId = const Value.absent(),
  });
  OutboxItemsCompanion.insert({
    this.id = const Value.absent(),
    required String clientUuid,
    required OutboxKind kind,
    required String payload,
    this.summary = const Value.absent(),
    this.state = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.serverState = const Value.absent(),
    required DateTime queuedAt,
    required DateTime updatedAt,
    this.nextAttemptAt = const Value.absent(),
    this.userId = const Value.absent(),
  }) : clientUuid = Value(clientUuid),
       kind = Value(kind),
       payload = Value(payload),
       queuedAt = Value(queuedAt),
       updatedAt = Value(updatedAt);
  static Insertable<OutboxRow> custom({
    Expression<int>? id,
    Expression<String>? clientUuid,
    Expression<int>? kind,
    Expression<String>? payload,
    Expression<String>? summary,
    Expression<int>? state,
    Expression<int>? attempts,
    Expression<String>? lastError,
    Expression<String>? errorCode,
    Expression<String>? serverState,
    Expression<DateTime>? queuedAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? nextAttemptAt,
    Expression<String>? userId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clientUuid != null) 'client_uuid': clientUuid,
      if (kind != null) 'kind': kind,
      if (payload != null) 'payload': payload,
      if (summary != null) 'summary': summary,
      if (state != null) 'state': state,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
      if (errorCode != null) 'error_code': errorCode,
      if (serverState != null) 'server_state': serverState,
      if (queuedAt != null) 'queued_at': queuedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (userId != null) 'user_id': userId,
    });
  }

  OutboxItemsCompanion copyWith({
    Value<int>? id,
    Value<String>? clientUuid,
    Value<OutboxKind>? kind,
    Value<String>? payload,
    Value<String>? summary,
    Value<OutboxState>? state,
    Value<int>? attempts,
    Value<String?>? lastError,
    Value<String?>? errorCode,
    Value<String?>? serverState,
    Value<DateTime>? queuedAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? nextAttemptAt,
    Value<String?>? userId,
  }) {
    return OutboxItemsCompanion(
      id: id ?? this.id,
      clientUuid: clientUuid ?? this.clientUuid,
      kind: kind ?? this.kind,
      payload: payload ?? this.payload,
      summary: summary ?? this.summary,
      state: state ?? this.state,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      errorCode: errorCode ?? this.errorCode,
      serverState: serverState ?? this.serverState,
      queuedAt: queuedAt ?? this.queuedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      userId: userId ?? this.userId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (clientUuid.present) {
      map['client_uuid'] = Variable<String>(clientUuid.value);
    }
    if (kind.present) {
      map['kind'] = Variable<int>(
        $OutboxItemsTable.$converterkind.toSql(kind.value),
      );
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (state.present) {
      map['state'] = Variable<int>(
        $OutboxItemsTable.$converterstate.toSql(state.value),
      );
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    if (serverState.present) {
      map['server_state'] = Variable<String>(serverState.value);
    }
    if (queuedAt.present) {
      map['queued_at'] = Variable<DateTime>(queuedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxItemsCompanion(')
          ..write('id: $id, ')
          ..write('clientUuid: $clientUuid, ')
          ..write('kind: $kind, ')
          ..write('payload: $payload, ')
          ..write('summary: $summary, ')
          ..write('state: $state, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('errorCode: $errorCode, ')
          ..write('serverState: $serverState, ')
          ..write('queuedAt: $queuedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('userId: $userId')
          ..write(')'))
        .toString();
  }
}

class $CachedPartsTable extends CachedParts
    with TableInfo<$CachedPartsTable, CachedPart> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedPartsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unpaintedPnMeta = const VerificationMeta(
    'unpaintedPn',
  );
  @override
  late final GeneratedColumn<String> unpaintedPn = GeneratedColumn<String>(
    'unpainted_pn',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paintedPnMeta = const VerificationMeta(
    'paintedPn',
  );
  @override
  late final GeneratedColumn<String> paintedPn = GeneratedColumn<String>(
    'painted_pn',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorShadeMeta = const VerificationMeta(
    'colorShade',
  );
  @override
  late final GeneratedColumn<String> colorShade = GeneratedColumn<String>(
    'color_shade',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _partTypeMeta = const VerificationMeta(
    'partType',
  );
  @override
  late final GeneratedColumn<String> partType = GeneratedColumn<String>(
    'part_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stationMeta = const VerificationMeta(
    'station',
  );
  @override
  late final GeneratedColumn<String> station = GeneratedColumn<String>(
    'station',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rackCodeMeta = const VerificationMeta(
    'rackCode',
  );
  @override
  late final GeneratedColumn<String> rackCode = GeneratedColumn<String>(
    'rack_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isBulkyMeta = const VerificationMeta(
    'isBulky',
  );
  @override
  late final GeneratedColumn<bool> isBulky = GeneratedColumn<bool>(
    'is_bulky',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_bulky" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _availableStockMeta = const VerificationMeta(
    'availableStock',
  );
  @override
  late final GeneratedColumn<double> availableStock = GeneratedColumn<double>(
    'available_stock',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    unpaintedPn,
    paintedPn,
    description,
    colorShade,
    partType,
    station,
    rackCode,
    isBulky,
    availableStock,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_parts';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedPart> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('unpainted_pn')) {
      context.handle(
        _unpaintedPnMeta,
        unpaintedPn.isAcceptableOrUnknown(
          data['unpainted_pn']!,
          _unpaintedPnMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_unpaintedPnMeta);
    }
    if (data.containsKey('painted_pn')) {
      context.handle(
        _paintedPnMeta,
        paintedPn.isAcceptableOrUnknown(data['painted_pn']!, _paintedPnMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('color_shade')) {
      context.handle(
        _colorShadeMeta,
        colorShade.isAcceptableOrUnknown(data['color_shade']!, _colorShadeMeta),
      );
    }
    if (data.containsKey('part_type')) {
      context.handle(
        _partTypeMeta,
        partType.isAcceptableOrUnknown(data['part_type']!, _partTypeMeta),
      );
    }
    if (data.containsKey('station')) {
      context.handle(
        _stationMeta,
        station.isAcceptableOrUnknown(data['station']!, _stationMeta),
      );
    }
    if (data.containsKey('rack_code')) {
      context.handle(
        _rackCodeMeta,
        rackCode.isAcceptableOrUnknown(data['rack_code']!, _rackCodeMeta),
      );
    }
    if (data.containsKey('is_bulky')) {
      context.handle(
        _isBulkyMeta,
        isBulky.isAcceptableOrUnknown(data['is_bulky']!, _isBulkyMeta),
      );
    }
    if (data.containsKey('available_stock')) {
      context.handle(
        _availableStockMeta,
        availableStock.isAcceptableOrUnknown(
          data['available_stock']!,
          _availableStockMeta,
        ),
      );
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedPart map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedPart(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      unpaintedPn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unpainted_pn'],
      )!,
      paintedPn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}painted_pn'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      colorShade: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_shade'],
      ),
      partType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}part_type'],
      ),
      station: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}station'],
      ),
      rackCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rack_code'],
      ),
      isBulky: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_bulky'],
      )!,
      availableStock: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}available_stock'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $CachedPartsTable createAlias(String alias) {
    return $CachedPartsTable(attachedDatabase, alias);
  }
}

class CachedPart extends DataClass implements Insertable<CachedPart> {
  final String id;
  final String unpaintedPn;
  final String? paintedPn;
  final String description;
  final String? colorShade;
  final String? partType;
  final String? station;
  final String? rackCode;
  final bool isBulky;
  final double availableStock;
  final DateTime cachedAt;
  const CachedPart({
    required this.id,
    required this.unpaintedPn,
    this.paintedPn,
    required this.description,
    this.colorShade,
    this.partType,
    this.station,
    this.rackCode,
    required this.isBulky,
    required this.availableStock,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['unpainted_pn'] = Variable<String>(unpaintedPn);
    if (!nullToAbsent || paintedPn != null) {
      map['painted_pn'] = Variable<String>(paintedPn);
    }
    map['description'] = Variable<String>(description);
    if (!nullToAbsent || colorShade != null) {
      map['color_shade'] = Variable<String>(colorShade);
    }
    if (!nullToAbsent || partType != null) {
      map['part_type'] = Variable<String>(partType);
    }
    if (!nullToAbsent || station != null) {
      map['station'] = Variable<String>(station);
    }
    if (!nullToAbsent || rackCode != null) {
      map['rack_code'] = Variable<String>(rackCode);
    }
    map['is_bulky'] = Variable<bool>(isBulky);
    map['available_stock'] = Variable<double>(availableStock);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CachedPartsCompanion toCompanion(bool nullToAbsent) {
    return CachedPartsCompanion(
      id: Value(id),
      unpaintedPn: Value(unpaintedPn),
      paintedPn: paintedPn == null && nullToAbsent
          ? const Value.absent()
          : Value(paintedPn),
      description: Value(description),
      colorShade: colorShade == null && nullToAbsent
          ? const Value.absent()
          : Value(colorShade),
      partType: partType == null && nullToAbsent
          ? const Value.absent()
          : Value(partType),
      station: station == null && nullToAbsent
          ? const Value.absent()
          : Value(station),
      rackCode: rackCode == null && nullToAbsent
          ? const Value.absent()
          : Value(rackCode),
      isBulky: Value(isBulky),
      availableStock: Value(availableStock),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedPart.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedPart(
      id: serializer.fromJson<String>(json['id']),
      unpaintedPn: serializer.fromJson<String>(json['unpaintedPn']),
      paintedPn: serializer.fromJson<String?>(json['paintedPn']),
      description: serializer.fromJson<String>(json['description']),
      colorShade: serializer.fromJson<String?>(json['colorShade']),
      partType: serializer.fromJson<String?>(json['partType']),
      station: serializer.fromJson<String?>(json['station']),
      rackCode: serializer.fromJson<String?>(json['rackCode']),
      isBulky: serializer.fromJson<bool>(json['isBulky']),
      availableStock: serializer.fromJson<double>(json['availableStock']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'unpaintedPn': serializer.toJson<String>(unpaintedPn),
      'paintedPn': serializer.toJson<String?>(paintedPn),
      'description': serializer.toJson<String>(description),
      'colorShade': serializer.toJson<String?>(colorShade),
      'partType': serializer.toJson<String?>(partType),
      'station': serializer.toJson<String?>(station),
      'rackCode': serializer.toJson<String?>(rackCode),
      'isBulky': serializer.toJson<bool>(isBulky),
      'availableStock': serializer.toJson<double>(availableStock),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CachedPart copyWith({
    String? id,
    String? unpaintedPn,
    Value<String?> paintedPn = const Value.absent(),
    String? description,
    Value<String?> colorShade = const Value.absent(),
    Value<String?> partType = const Value.absent(),
    Value<String?> station = const Value.absent(),
    Value<String?> rackCode = const Value.absent(),
    bool? isBulky,
    double? availableStock,
    DateTime? cachedAt,
  }) => CachedPart(
    id: id ?? this.id,
    unpaintedPn: unpaintedPn ?? this.unpaintedPn,
    paintedPn: paintedPn.present ? paintedPn.value : this.paintedPn,
    description: description ?? this.description,
    colorShade: colorShade.present ? colorShade.value : this.colorShade,
    partType: partType.present ? partType.value : this.partType,
    station: station.present ? station.value : this.station,
    rackCode: rackCode.present ? rackCode.value : this.rackCode,
    isBulky: isBulky ?? this.isBulky,
    availableStock: availableStock ?? this.availableStock,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  CachedPart copyWithCompanion(CachedPartsCompanion data) {
    return CachedPart(
      id: data.id.present ? data.id.value : this.id,
      unpaintedPn: data.unpaintedPn.present
          ? data.unpaintedPn.value
          : this.unpaintedPn,
      paintedPn: data.paintedPn.present ? data.paintedPn.value : this.paintedPn,
      description: data.description.present
          ? data.description.value
          : this.description,
      colorShade: data.colorShade.present
          ? data.colorShade.value
          : this.colorShade,
      partType: data.partType.present ? data.partType.value : this.partType,
      station: data.station.present ? data.station.value : this.station,
      rackCode: data.rackCode.present ? data.rackCode.value : this.rackCode,
      isBulky: data.isBulky.present ? data.isBulky.value : this.isBulky,
      availableStock: data.availableStock.present
          ? data.availableStock.value
          : this.availableStock,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedPart(')
          ..write('id: $id, ')
          ..write('unpaintedPn: $unpaintedPn, ')
          ..write('paintedPn: $paintedPn, ')
          ..write('description: $description, ')
          ..write('colorShade: $colorShade, ')
          ..write('partType: $partType, ')
          ..write('station: $station, ')
          ..write('rackCode: $rackCode, ')
          ..write('isBulky: $isBulky, ')
          ..write('availableStock: $availableStock, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    unpaintedPn,
    paintedPn,
    description,
    colorShade,
    partType,
    station,
    rackCode,
    isBulky,
    availableStock,
    cachedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedPart &&
          other.id == this.id &&
          other.unpaintedPn == this.unpaintedPn &&
          other.paintedPn == this.paintedPn &&
          other.description == this.description &&
          other.colorShade == this.colorShade &&
          other.partType == this.partType &&
          other.station == this.station &&
          other.rackCode == this.rackCode &&
          other.isBulky == this.isBulky &&
          other.availableStock == this.availableStock &&
          other.cachedAt == this.cachedAt);
}

class CachedPartsCompanion extends UpdateCompanion<CachedPart> {
  final Value<String> id;
  final Value<String> unpaintedPn;
  final Value<String?> paintedPn;
  final Value<String> description;
  final Value<String?> colorShade;
  final Value<String?> partType;
  final Value<String?> station;
  final Value<String?> rackCode;
  final Value<bool> isBulky;
  final Value<double> availableStock;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const CachedPartsCompanion({
    this.id = const Value.absent(),
    this.unpaintedPn = const Value.absent(),
    this.paintedPn = const Value.absent(),
    this.description = const Value.absent(),
    this.colorShade = const Value.absent(),
    this.partType = const Value.absent(),
    this.station = const Value.absent(),
    this.rackCode = const Value.absent(),
    this.isBulky = const Value.absent(),
    this.availableStock = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedPartsCompanion.insert({
    required String id,
    required String unpaintedPn,
    this.paintedPn = const Value.absent(),
    required String description,
    this.colorShade = const Value.absent(),
    this.partType = const Value.absent(),
    this.station = const Value.absent(),
    this.rackCode = const Value.absent(),
    this.isBulky = const Value.absent(),
    this.availableStock = const Value.absent(),
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       unpaintedPn = Value(unpaintedPn),
       description = Value(description),
       cachedAt = Value(cachedAt);
  static Insertable<CachedPart> custom({
    Expression<String>? id,
    Expression<String>? unpaintedPn,
    Expression<String>? paintedPn,
    Expression<String>? description,
    Expression<String>? colorShade,
    Expression<String>? partType,
    Expression<String>? station,
    Expression<String>? rackCode,
    Expression<bool>? isBulky,
    Expression<double>? availableStock,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (unpaintedPn != null) 'unpainted_pn': unpaintedPn,
      if (paintedPn != null) 'painted_pn': paintedPn,
      if (description != null) 'description': description,
      if (colorShade != null) 'color_shade': colorShade,
      if (partType != null) 'part_type': partType,
      if (station != null) 'station': station,
      if (rackCode != null) 'rack_code': rackCode,
      if (isBulky != null) 'is_bulky': isBulky,
      if (availableStock != null) 'available_stock': availableStock,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedPartsCompanion copyWith({
    Value<String>? id,
    Value<String>? unpaintedPn,
    Value<String?>? paintedPn,
    Value<String>? description,
    Value<String?>? colorShade,
    Value<String?>? partType,
    Value<String?>? station,
    Value<String?>? rackCode,
    Value<bool>? isBulky,
    Value<double>? availableStock,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return CachedPartsCompanion(
      id: id ?? this.id,
      unpaintedPn: unpaintedPn ?? this.unpaintedPn,
      paintedPn: paintedPn ?? this.paintedPn,
      description: description ?? this.description,
      colorShade: colorShade ?? this.colorShade,
      partType: partType ?? this.partType,
      station: station ?? this.station,
      rackCode: rackCode ?? this.rackCode,
      isBulky: isBulky ?? this.isBulky,
      availableStock: availableStock ?? this.availableStock,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (unpaintedPn.present) {
      map['unpainted_pn'] = Variable<String>(unpaintedPn.value);
    }
    if (paintedPn.present) {
      map['painted_pn'] = Variable<String>(paintedPn.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (colorShade.present) {
      map['color_shade'] = Variable<String>(colorShade.value);
    }
    if (partType.present) {
      map['part_type'] = Variable<String>(partType.value);
    }
    if (station.present) {
      map['station'] = Variable<String>(station.value);
    }
    if (rackCode.present) {
      map['rack_code'] = Variable<String>(rackCode.value);
    }
    if (isBulky.present) {
      map['is_bulky'] = Variable<bool>(isBulky.value);
    }
    if (availableStock.present) {
      map['available_stock'] = Variable<double>(availableStock.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedPartsCompanion(')
          ..write('id: $id, ')
          ..write('unpaintedPn: $unpaintedPn, ')
          ..write('paintedPn: $paintedPn, ')
          ..write('description: $description, ')
          ..write('colorShade: $colorShade, ')
          ..write('partType: $partType, ')
          ..write('station: $station, ')
          ..write('rackCode: $rackCode, ')
          ..write('isBulky: $isBulky, ')
          ..write('availableStock: $availableStock, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedPatternsTable extends CachedPatterns
    with TableInfo<$CachedPatternsTable, CachedPattern> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedPatternsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lineIdMeta = const VerificationMeta('lineId');
  @override
  late final GeneratedColumn<String> lineId = GeneratedColumn<String>(
    'line_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _plannedSurfaceMeta = const VerificationMeta(
    'plannedSurface',
  );
  @override
  late final GeneratedColumn<double> plannedSurface = GeneratedColumn<double>(
    'planned_surface',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _shadeMeta = const VerificationMeta('shade');
  @override
  late final GeneratedColumn<String> shade = GeneratedColumn<String>(
    'shade',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isSpecialMeta = const VerificationMeta(
    'isSpecial',
  );
  @override
  late final GeneratedColumn<bool> isSpecial = GeneratedColumn<bool>(
    'is_special',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_special" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _approvedMeta = const VerificationMeta(
    'approved',
  );
  @override
  late final GeneratedColumn<bool> approved = GeneratedColumn<bool>(
    'approved',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("approved" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _itemsJsonMeta = const VerificationMeta(
    'itemsJson',
  );
  @override
  late final GeneratedColumn<String> itemsJson = GeneratedColumn<String>(
    'items_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    lineId,
    code,
    name,
    plannedSurface,
    shade,
    isSpecial,
    approved,
    itemsJson,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_patterns';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedPattern> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('line_id')) {
      context.handle(
        _lineIdMeta,
        lineId.isAcceptableOrUnknown(data['line_id']!, _lineIdMeta),
      );
    } else if (isInserting) {
      context.missing(_lineIdMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('planned_surface')) {
      context.handle(
        _plannedSurfaceMeta,
        plannedSurface.isAcceptableOrUnknown(
          data['planned_surface']!,
          _plannedSurfaceMeta,
        ),
      );
    }
    if (data.containsKey('shade')) {
      context.handle(
        _shadeMeta,
        shade.isAcceptableOrUnknown(data['shade']!, _shadeMeta),
      );
    }
    if (data.containsKey('is_special')) {
      context.handle(
        _isSpecialMeta,
        isSpecial.isAcceptableOrUnknown(data['is_special']!, _isSpecialMeta),
      );
    }
    if (data.containsKey('approved')) {
      context.handle(
        _approvedMeta,
        approved.isAcceptableOrUnknown(data['approved']!, _approvedMeta),
      );
    }
    if (data.containsKey('items_json')) {
      context.handle(
        _itemsJsonMeta,
        itemsJson.isAcceptableOrUnknown(data['items_json']!, _itemsJsonMeta),
      );
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedPattern map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedPattern(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      lineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}line_id'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      plannedSurface: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}planned_surface'],
      ),
      shade: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shade'],
      ),
      isSpecial: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_special'],
      )!,
      approved: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}approved'],
      )!,
      itemsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}items_json'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $CachedPatternsTable createAlias(String alias) {
    return $CachedPatternsTable(attachedDatabase, alias);
  }
}

class CachedPattern extends DataClass implements Insertable<CachedPattern> {
  final String id;
  final String lineId;
  final String code;
  final String? name;
  final double? plannedSurface;
  final String? shade;
  final bool isSpecial;
  final bool approved;

  /// The frame's parts as JSON: `[{part_id, seq_no, qty_per_frame}]`. Stored
  /// denormalised because it is always read as a whole frame, never queried
  /// across patterns.
  final String itemsJson;
  final DateTime cachedAt;
  const CachedPattern({
    required this.id,
    required this.lineId,
    required this.code,
    this.name,
    this.plannedSurface,
    this.shade,
    required this.isSpecial,
    required this.approved,
    required this.itemsJson,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['line_id'] = Variable<String>(lineId);
    map['code'] = Variable<String>(code);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || plannedSurface != null) {
      map['planned_surface'] = Variable<double>(plannedSurface);
    }
    if (!nullToAbsent || shade != null) {
      map['shade'] = Variable<String>(shade);
    }
    map['is_special'] = Variable<bool>(isSpecial);
    map['approved'] = Variable<bool>(approved);
    map['items_json'] = Variable<String>(itemsJson);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CachedPatternsCompanion toCompanion(bool nullToAbsent) {
    return CachedPatternsCompanion(
      id: Value(id),
      lineId: Value(lineId),
      code: Value(code),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      plannedSurface: plannedSurface == null && nullToAbsent
          ? const Value.absent()
          : Value(plannedSurface),
      shade: shade == null && nullToAbsent
          ? const Value.absent()
          : Value(shade),
      isSpecial: Value(isSpecial),
      approved: Value(approved),
      itemsJson: Value(itemsJson),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedPattern.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedPattern(
      id: serializer.fromJson<String>(json['id']),
      lineId: serializer.fromJson<String>(json['lineId']),
      code: serializer.fromJson<String>(json['code']),
      name: serializer.fromJson<String?>(json['name']),
      plannedSurface: serializer.fromJson<double?>(json['plannedSurface']),
      shade: serializer.fromJson<String?>(json['shade']),
      isSpecial: serializer.fromJson<bool>(json['isSpecial']),
      approved: serializer.fromJson<bool>(json['approved']),
      itemsJson: serializer.fromJson<String>(json['itemsJson']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'lineId': serializer.toJson<String>(lineId),
      'code': serializer.toJson<String>(code),
      'name': serializer.toJson<String?>(name),
      'plannedSurface': serializer.toJson<double?>(plannedSurface),
      'shade': serializer.toJson<String?>(shade),
      'isSpecial': serializer.toJson<bool>(isSpecial),
      'approved': serializer.toJson<bool>(approved),
      'itemsJson': serializer.toJson<String>(itemsJson),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CachedPattern copyWith({
    String? id,
    String? lineId,
    String? code,
    Value<String?> name = const Value.absent(),
    Value<double?> plannedSurface = const Value.absent(),
    Value<String?> shade = const Value.absent(),
    bool? isSpecial,
    bool? approved,
    String? itemsJson,
    DateTime? cachedAt,
  }) => CachedPattern(
    id: id ?? this.id,
    lineId: lineId ?? this.lineId,
    code: code ?? this.code,
    name: name.present ? name.value : this.name,
    plannedSurface: plannedSurface.present
        ? plannedSurface.value
        : this.plannedSurface,
    shade: shade.present ? shade.value : this.shade,
    isSpecial: isSpecial ?? this.isSpecial,
    approved: approved ?? this.approved,
    itemsJson: itemsJson ?? this.itemsJson,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  CachedPattern copyWithCompanion(CachedPatternsCompanion data) {
    return CachedPattern(
      id: data.id.present ? data.id.value : this.id,
      lineId: data.lineId.present ? data.lineId.value : this.lineId,
      code: data.code.present ? data.code.value : this.code,
      name: data.name.present ? data.name.value : this.name,
      plannedSurface: data.plannedSurface.present
          ? data.plannedSurface.value
          : this.plannedSurface,
      shade: data.shade.present ? data.shade.value : this.shade,
      isSpecial: data.isSpecial.present ? data.isSpecial.value : this.isSpecial,
      approved: data.approved.present ? data.approved.value : this.approved,
      itemsJson: data.itemsJson.present ? data.itemsJson.value : this.itemsJson,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedPattern(')
          ..write('id: $id, ')
          ..write('lineId: $lineId, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('plannedSurface: $plannedSurface, ')
          ..write('shade: $shade, ')
          ..write('isSpecial: $isSpecial, ')
          ..write('approved: $approved, ')
          ..write('itemsJson: $itemsJson, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    lineId,
    code,
    name,
    plannedSurface,
    shade,
    isSpecial,
    approved,
    itemsJson,
    cachedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedPattern &&
          other.id == this.id &&
          other.lineId == this.lineId &&
          other.code == this.code &&
          other.name == this.name &&
          other.plannedSurface == this.plannedSurface &&
          other.shade == this.shade &&
          other.isSpecial == this.isSpecial &&
          other.approved == this.approved &&
          other.itemsJson == this.itemsJson &&
          other.cachedAt == this.cachedAt);
}

class CachedPatternsCompanion extends UpdateCompanion<CachedPattern> {
  final Value<String> id;
  final Value<String> lineId;
  final Value<String> code;
  final Value<String?> name;
  final Value<double?> plannedSurface;
  final Value<String?> shade;
  final Value<bool> isSpecial;
  final Value<bool> approved;
  final Value<String> itemsJson;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const CachedPatternsCompanion({
    this.id = const Value.absent(),
    this.lineId = const Value.absent(),
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.plannedSurface = const Value.absent(),
    this.shade = const Value.absent(),
    this.isSpecial = const Value.absent(),
    this.approved = const Value.absent(),
    this.itemsJson = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedPatternsCompanion.insert({
    required String id,
    required String lineId,
    required String code,
    this.name = const Value.absent(),
    this.plannedSurface = const Value.absent(),
    this.shade = const Value.absent(),
    this.isSpecial = const Value.absent(),
    this.approved = const Value.absent(),
    this.itemsJson = const Value.absent(),
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       lineId = Value(lineId),
       code = Value(code),
       cachedAt = Value(cachedAt);
  static Insertable<CachedPattern> custom({
    Expression<String>? id,
    Expression<String>? lineId,
    Expression<String>? code,
    Expression<String>? name,
    Expression<double>? plannedSurface,
    Expression<String>? shade,
    Expression<bool>? isSpecial,
    Expression<bool>? approved,
    Expression<String>? itemsJson,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (lineId != null) 'line_id': lineId,
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (plannedSurface != null) 'planned_surface': plannedSurface,
      if (shade != null) 'shade': shade,
      if (isSpecial != null) 'is_special': isSpecial,
      if (approved != null) 'approved': approved,
      if (itemsJson != null) 'items_json': itemsJson,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedPatternsCompanion copyWith({
    Value<String>? id,
    Value<String>? lineId,
    Value<String>? code,
    Value<String?>? name,
    Value<double?>? plannedSurface,
    Value<String?>? shade,
    Value<bool>? isSpecial,
    Value<bool>? approved,
    Value<String>? itemsJson,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return CachedPatternsCompanion(
      id: id ?? this.id,
      lineId: lineId ?? this.lineId,
      code: code ?? this.code,
      name: name ?? this.name,
      plannedSurface: plannedSurface ?? this.plannedSurface,
      shade: shade ?? this.shade,
      isSpecial: isSpecial ?? this.isSpecial,
      approved: approved ?? this.approved,
      itemsJson: itemsJson ?? this.itemsJson,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (lineId.present) {
      map['line_id'] = Variable<String>(lineId.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (plannedSurface.present) {
      map['planned_surface'] = Variable<double>(plannedSurface.value);
    }
    if (shade.present) {
      map['shade'] = Variable<String>(shade.value);
    }
    if (isSpecial.present) {
      map['is_special'] = Variable<bool>(isSpecial.value);
    }
    if (approved.present) {
      map['approved'] = Variable<bool>(approved.value);
    }
    if (itemsJson.present) {
      map['items_json'] = Variable<String>(itemsJson.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedPatternsCompanion(')
          ..write('id: $id, ')
          ..write('lineId: $lineId, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('plannedSurface: $plannedSurface, ')
          ..write('shade: $shade, ')
          ..write('isSpecial: $isSpecial, ')
          ..write('approved: $approved, ')
          ..write('itemsJson: $itemsJson, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedLinesTable extends CachedLines
    with TableInfo<$CachedLinesTable, CachedLine> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedLinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _yellowThresholdMeta = const VerificationMeta(
    'yellowThreshold',
  );
  @override
  late final GeneratedColumn<int> yellowThreshold = GeneratedColumn<int>(
    'yellow_threshold',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(10),
  );
  static const VerificationMeta _redThresholdMeta = const VerificationMeta(
    'redThreshold',
  );
  @override
  late final GeneratedColumn<int> redThreshold = GeneratedColumn<int>(
    'red_threshold',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(5),
  );
  static const VerificationMeta _runsDriveConsumptionMeta =
      const VerificationMeta('runsDriveConsumption');
  @override
  late final GeneratedColumn<bool> runsDriveConsumption = GeneratedColumn<bool>(
    'runs_drive_consumption',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("runs_drive_consumption" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    code,
    name,
    yellowThreshold,
    redThreshold,
    runsDriveConsumption,
    sortOrder,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_lines';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedLine> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('yellow_threshold')) {
      context.handle(
        _yellowThresholdMeta,
        yellowThreshold.isAcceptableOrUnknown(
          data['yellow_threshold']!,
          _yellowThresholdMeta,
        ),
      );
    }
    if (data.containsKey('red_threshold')) {
      context.handle(
        _redThresholdMeta,
        redThreshold.isAcceptableOrUnknown(
          data['red_threshold']!,
          _redThresholdMeta,
        ),
      );
    }
    if (data.containsKey('runs_drive_consumption')) {
      context.handle(
        _runsDriveConsumptionMeta,
        runsDriveConsumption.isAcceptableOrUnknown(
          data['runs_drive_consumption']!,
          _runsDriveConsumptionMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedLine map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedLine(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      yellowThreshold: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}yellow_threshold'],
      )!,
      redThreshold: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}red_threshold'],
      )!,
      runsDriveConsumption: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}runs_drive_consumption'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $CachedLinesTable createAlias(String alias) {
    return $CachedLinesTable(attachedDatabase, alias);
  }
}

class CachedLine extends DataClass implements Insertable<CachedLine> {
  final String id;
  final String code;
  final String name;
  final int yellowThreshold;
  final int redThreshold;
  final bool runsDriveConsumption;
  final int sortOrder;
  final DateTime cachedAt;
  const CachedLine({
    required this.id,
    required this.code,
    required this.name,
    required this.yellowThreshold,
    required this.redThreshold,
    required this.runsDriveConsumption,
    required this.sortOrder,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['code'] = Variable<String>(code);
    map['name'] = Variable<String>(name);
    map['yellow_threshold'] = Variable<int>(yellowThreshold);
    map['red_threshold'] = Variable<int>(redThreshold);
    map['runs_drive_consumption'] = Variable<bool>(runsDriveConsumption);
    map['sort_order'] = Variable<int>(sortOrder);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CachedLinesCompanion toCompanion(bool nullToAbsent) {
    return CachedLinesCompanion(
      id: Value(id),
      code: Value(code),
      name: Value(name),
      yellowThreshold: Value(yellowThreshold),
      redThreshold: Value(redThreshold),
      runsDriveConsumption: Value(runsDriveConsumption),
      sortOrder: Value(sortOrder),
      cachedAt: Value(cachedAt),
    );
  }

  factory CachedLine.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedLine(
      id: serializer.fromJson<String>(json['id']),
      code: serializer.fromJson<String>(json['code']),
      name: serializer.fromJson<String>(json['name']),
      yellowThreshold: serializer.fromJson<int>(json['yellowThreshold']),
      redThreshold: serializer.fromJson<int>(json['redThreshold']),
      runsDriveConsumption: serializer.fromJson<bool>(
        json['runsDriveConsumption'],
      ),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'code': serializer.toJson<String>(code),
      'name': serializer.toJson<String>(name),
      'yellowThreshold': serializer.toJson<int>(yellowThreshold),
      'redThreshold': serializer.toJson<int>(redThreshold),
      'runsDriveConsumption': serializer.toJson<bool>(runsDriveConsumption),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CachedLine copyWith({
    String? id,
    String? code,
    String? name,
    int? yellowThreshold,
    int? redThreshold,
    bool? runsDriveConsumption,
    int? sortOrder,
    DateTime? cachedAt,
  }) => CachedLine(
    id: id ?? this.id,
    code: code ?? this.code,
    name: name ?? this.name,
    yellowThreshold: yellowThreshold ?? this.yellowThreshold,
    redThreshold: redThreshold ?? this.redThreshold,
    runsDriveConsumption: runsDriveConsumption ?? this.runsDriveConsumption,
    sortOrder: sortOrder ?? this.sortOrder,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  CachedLine copyWithCompanion(CachedLinesCompanion data) {
    return CachedLine(
      id: data.id.present ? data.id.value : this.id,
      code: data.code.present ? data.code.value : this.code,
      name: data.name.present ? data.name.value : this.name,
      yellowThreshold: data.yellowThreshold.present
          ? data.yellowThreshold.value
          : this.yellowThreshold,
      redThreshold: data.redThreshold.present
          ? data.redThreshold.value
          : this.redThreshold,
      runsDriveConsumption: data.runsDriveConsumption.present
          ? data.runsDriveConsumption.value
          : this.runsDriveConsumption,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedLine(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('yellowThreshold: $yellowThreshold, ')
          ..write('redThreshold: $redThreshold, ')
          ..write('runsDriveConsumption: $runsDriveConsumption, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    code,
    name,
    yellowThreshold,
    redThreshold,
    runsDriveConsumption,
    sortOrder,
    cachedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedLine &&
          other.id == this.id &&
          other.code == this.code &&
          other.name == this.name &&
          other.yellowThreshold == this.yellowThreshold &&
          other.redThreshold == this.redThreshold &&
          other.runsDriveConsumption == this.runsDriveConsumption &&
          other.sortOrder == this.sortOrder &&
          other.cachedAt == this.cachedAt);
}

class CachedLinesCompanion extends UpdateCompanion<CachedLine> {
  final Value<String> id;
  final Value<String> code;
  final Value<String> name;
  final Value<int> yellowThreshold;
  final Value<int> redThreshold;
  final Value<bool> runsDriveConsumption;
  final Value<int> sortOrder;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const CachedLinesCompanion({
    this.id = const Value.absent(),
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.yellowThreshold = const Value.absent(),
    this.redThreshold = const Value.absent(),
    this.runsDriveConsumption = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedLinesCompanion.insert({
    required String id,
    required String code,
    required String name,
    this.yellowThreshold = const Value.absent(),
    this.redThreshold = const Value.absent(),
    this.runsDriveConsumption = const Value.absent(),
    this.sortOrder = const Value.absent(),
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       code = Value(code),
       name = Value(name),
       cachedAt = Value(cachedAt);
  static Insertable<CachedLine> custom({
    Expression<String>? id,
    Expression<String>? code,
    Expression<String>? name,
    Expression<int>? yellowThreshold,
    Expression<int>? redThreshold,
    Expression<bool>? runsDriveConsumption,
    Expression<int>? sortOrder,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (yellowThreshold != null) 'yellow_threshold': yellowThreshold,
      if (redThreshold != null) 'red_threshold': redThreshold,
      if (runsDriveConsumption != null)
        'runs_drive_consumption': runsDriveConsumption,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedLinesCompanion copyWith({
    Value<String>? id,
    Value<String>? code,
    Value<String>? name,
    Value<int>? yellowThreshold,
    Value<int>? redThreshold,
    Value<bool>? runsDriveConsumption,
    Value<int>? sortOrder,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return CachedLinesCompanion(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      yellowThreshold: yellowThreshold ?? this.yellowThreshold,
      redThreshold: redThreshold ?? this.redThreshold,
      runsDriveConsumption: runsDriveConsumption ?? this.runsDriveConsumption,
      sortOrder: sortOrder ?? this.sortOrder,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (yellowThreshold.present) {
      map['yellow_threshold'] = Variable<int>(yellowThreshold.value);
    }
    if (redThreshold.present) {
      map['red_threshold'] = Variable<int>(redThreshold.value);
    }
    if (runsDriveConsumption.present) {
      map['runs_drive_consumption'] = Variable<bool>(
        runsDriveConsumption.value,
      );
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedLinesCompanion(')
          ..write('id: $id, ')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('yellowThreshold: $yellowThreshold, ')
          ..write('redThreshold: $redThreshold, ')
          ..write('runsDriveConsumption: $runsDriveConsumption, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingPhotosTable extends PendingPhotos
    with TableInfo<$PendingPhotosTable, PendingPhoto> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingPhotosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _clientUuidMeta = const VerificationMeta(
    'clientUuid',
  );
  @override
  late final GeneratedColumn<String> clientUuid = GeneratedColumn<String>(
    'client_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<Uint8List> bytes = GeneratedColumn<Uint8List>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('image/jpeg'),
  );
  static const VerificationMeta _lineIdMeta = const VerificationMeta('lineId');
  @override
  late final GeneratedColumn<String> lineId = GeneratedColumn<String>(
    'line_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _patternIdMeta = const VerificationMeta(
    'patternId',
  );
  @override
  late final GeneratedColumn<String> patternId = GeneratedColumn<String>(
    'pattern_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nestingFrameNoMeta = const VerificationMeta(
    'nestingFrameNo',
  );
  @override
  late final GeneratedColumn<String> nestingFrameNo = GeneratedColumn<String>(
    'nesting_frame_no',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _capturedAtMeta = const VerificationMeta(
    'capturedAt',
  );
  @override
  late final GeneratedColumn<DateTime> capturedAt = GeneratedColumn<DateTime>(
    'captured_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    clientUuid,
    bytes,
    mimeType,
    lineId,
    patternId,
    nestingFrameNo,
    capturedAt,
    attempts,
    lastError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_photos';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingPhoto> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('client_uuid')) {
      context.handle(
        _clientUuidMeta,
        clientUuid.isAcceptableOrUnknown(data['client_uuid']!, _clientUuidMeta),
      );
    } else if (isInserting) {
      context.missing(_clientUuidMeta);
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    } else if (isInserting) {
      context.missing(_bytesMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    }
    if (data.containsKey('line_id')) {
      context.handle(
        _lineIdMeta,
        lineId.isAcceptableOrUnknown(data['line_id']!, _lineIdMeta),
      );
    }
    if (data.containsKey('pattern_id')) {
      context.handle(
        _patternIdMeta,
        patternId.isAcceptableOrUnknown(data['pattern_id']!, _patternIdMeta),
      );
    }
    if (data.containsKey('nesting_frame_no')) {
      context.handle(
        _nestingFrameNoMeta,
        nestingFrameNo.isAcceptableOrUnknown(
          data['nesting_frame_no']!,
          _nestingFrameNoMeta,
        ),
      );
    }
    if (data.containsKey('captured_at')) {
      context.handle(
        _capturedAtMeta,
        capturedAt.isAcceptableOrUnknown(data['captured_at']!, _capturedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_capturedAtMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingPhoto map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingPhoto(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      clientUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_uuid'],
      )!,
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}bytes'],
      )!,
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      )!,
      lineId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}line_id'],
      ),
      patternId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pattern_id'],
      ),
      nestingFrameNo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nesting_frame_no'],
      ),
      capturedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}captured_at'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
    );
  }

  @override
  $PendingPhotosTable createAlias(String alias) {
    return $PendingPhotosTable(attachedDatabase, alias);
  }
}

class PendingPhoto extends DataClass implements Insertable<PendingPhoto> {
  final int id;

  /// Generated on THIS device at capture. The server dedupes on it, so a
  /// retried upload can never store a second copy of the same megabyte.
  final String clientUuid;
  final Uint8List bytes;
  final String mimeType;
  final String? lineId;
  final String? patternId;
  final String? nestingFrameNo;
  final DateTime capturedAt;
  final int attempts;
  final String? lastError;
  const PendingPhoto({
    required this.id,
    required this.clientUuid,
    required this.bytes,
    required this.mimeType,
    this.lineId,
    this.patternId,
    this.nestingFrameNo,
    required this.capturedAt,
    required this.attempts,
    this.lastError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['client_uuid'] = Variable<String>(clientUuid);
    map['bytes'] = Variable<Uint8List>(bytes);
    map['mime_type'] = Variable<String>(mimeType);
    if (!nullToAbsent || lineId != null) {
      map['line_id'] = Variable<String>(lineId);
    }
    if (!nullToAbsent || patternId != null) {
      map['pattern_id'] = Variable<String>(patternId);
    }
    if (!nullToAbsent || nestingFrameNo != null) {
      map['nesting_frame_no'] = Variable<String>(nestingFrameNo);
    }
    map['captured_at'] = Variable<DateTime>(capturedAt);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  PendingPhotosCompanion toCompanion(bool nullToAbsent) {
    return PendingPhotosCompanion(
      id: Value(id),
      clientUuid: Value(clientUuid),
      bytes: Value(bytes),
      mimeType: Value(mimeType),
      lineId: lineId == null && nullToAbsent
          ? const Value.absent()
          : Value(lineId),
      patternId: patternId == null && nullToAbsent
          ? const Value.absent()
          : Value(patternId),
      nestingFrameNo: nestingFrameNo == null && nullToAbsent
          ? const Value.absent()
          : Value(nestingFrameNo),
      capturedAt: Value(capturedAt),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory PendingPhoto.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingPhoto(
      id: serializer.fromJson<int>(json['id']),
      clientUuid: serializer.fromJson<String>(json['clientUuid']),
      bytes: serializer.fromJson<Uint8List>(json['bytes']),
      mimeType: serializer.fromJson<String>(json['mimeType']),
      lineId: serializer.fromJson<String?>(json['lineId']),
      patternId: serializer.fromJson<String?>(json['patternId']),
      nestingFrameNo: serializer.fromJson<String?>(json['nestingFrameNo']),
      capturedAt: serializer.fromJson<DateTime>(json['capturedAt']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'clientUuid': serializer.toJson<String>(clientUuid),
      'bytes': serializer.toJson<Uint8List>(bytes),
      'mimeType': serializer.toJson<String>(mimeType),
      'lineId': serializer.toJson<String?>(lineId),
      'patternId': serializer.toJson<String?>(patternId),
      'nestingFrameNo': serializer.toJson<String?>(nestingFrameNo),
      'capturedAt': serializer.toJson<DateTime>(capturedAt),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  PendingPhoto copyWith({
    int? id,
    String? clientUuid,
    Uint8List? bytes,
    String? mimeType,
    Value<String?> lineId = const Value.absent(),
    Value<String?> patternId = const Value.absent(),
    Value<String?> nestingFrameNo = const Value.absent(),
    DateTime? capturedAt,
    int? attempts,
    Value<String?> lastError = const Value.absent(),
  }) => PendingPhoto(
    id: id ?? this.id,
    clientUuid: clientUuid ?? this.clientUuid,
    bytes: bytes ?? this.bytes,
    mimeType: mimeType ?? this.mimeType,
    lineId: lineId.present ? lineId.value : this.lineId,
    patternId: patternId.present ? patternId.value : this.patternId,
    nestingFrameNo: nestingFrameNo.present
        ? nestingFrameNo.value
        : this.nestingFrameNo,
    capturedAt: capturedAt ?? this.capturedAt,
    attempts: attempts ?? this.attempts,
    lastError: lastError.present ? lastError.value : this.lastError,
  );
  PendingPhoto copyWithCompanion(PendingPhotosCompanion data) {
    return PendingPhoto(
      id: data.id.present ? data.id.value : this.id,
      clientUuid: data.clientUuid.present
          ? data.clientUuid.value
          : this.clientUuid,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      lineId: data.lineId.present ? data.lineId.value : this.lineId,
      patternId: data.patternId.present ? data.patternId.value : this.patternId,
      nestingFrameNo: data.nestingFrameNo.present
          ? data.nestingFrameNo.value
          : this.nestingFrameNo,
      capturedAt: data.capturedAt.present
          ? data.capturedAt.value
          : this.capturedAt,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingPhoto(')
          ..write('id: $id, ')
          ..write('clientUuid: $clientUuid, ')
          ..write('bytes: $bytes, ')
          ..write('mimeType: $mimeType, ')
          ..write('lineId: $lineId, ')
          ..write('patternId: $patternId, ')
          ..write('nestingFrameNo: $nestingFrameNo, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    clientUuid,
    $driftBlobEquality.hash(bytes),
    mimeType,
    lineId,
    patternId,
    nestingFrameNo,
    capturedAt,
    attempts,
    lastError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingPhoto &&
          other.id == this.id &&
          other.clientUuid == this.clientUuid &&
          $driftBlobEquality.equals(other.bytes, this.bytes) &&
          other.mimeType == this.mimeType &&
          other.lineId == this.lineId &&
          other.patternId == this.patternId &&
          other.nestingFrameNo == this.nestingFrameNo &&
          other.capturedAt == this.capturedAt &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError);
}

class PendingPhotosCompanion extends UpdateCompanion<PendingPhoto> {
  final Value<int> id;
  final Value<String> clientUuid;
  final Value<Uint8List> bytes;
  final Value<String> mimeType;
  final Value<String?> lineId;
  final Value<String?> patternId;
  final Value<String?> nestingFrameNo;
  final Value<DateTime> capturedAt;
  final Value<int> attempts;
  final Value<String?> lastError;
  const PendingPhotosCompanion({
    this.id = const Value.absent(),
    this.clientUuid = const Value.absent(),
    this.bytes = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.lineId = const Value.absent(),
    this.patternId = const Value.absent(),
    this.nestingFrameNo = const Value.absent(),
    this.capturedAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
  });
  PendingPhotosCompanion.insert({
    this.id = const Value.absent(),
    required String clientUuid,
    required Uint8List bytes,
    this.mimeType = const Value.absent(),
    this.lineId = const Value.absent(),
    this.patternId = const Value.absent(),
    this.nestingFrameNo = const Value.absent(),
    required DateTime capturedAt,
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
  }) : clientUuid = Value(clientUuid),
       bytes = Value(bytes),
       capturedAt = Value(capturedAt);
  static Insertable<PendingPhoto> custom({
    Expression<int>? id,
    Expression<String>? clientUuid,
    Expression<Uint8List>? bytes,
    Expression<String>? mimeType,
    Expression<String>? lineId,
    Expression<String>? patternId,
    Expression<String>? nestingFrameNo,
    Expression<DateTime>? capturedAt,
    Expression<int>? attempts,
    Expression<String>? lastError,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clientUuid != null) 'client_uuid': clientUuid,
      if (bytes != null) 'bytes': bytes,
      if (mimeType != null) 'mime_type': mimeType,
      if (lineId != null) 'line_id': lineId,
      if (patternId != null) 'pattern_id': patternId,
      if (nestingFrameNo != null) 'nesting_frame_no': nestingFrameNo,
      if (capturedAt != null) 'captured_at': capturedAt,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
    });
  }

  PendingPhotosCompanion copyWith({
    Value<int>? id,
    Value<String>? clientUuid,
    Value<Uint8List>? bytes,
    Value<String>? mimeType,
    Value<String?>? lineId,
    Value<String?>? patternId,
    Value<String?>? nestingFrameNo,
    Value<DateTime>? capturedAt,
    Value<int>? attempts,
    Value<String?>? lastError,
  }) {
    return PendingPhotosCompanion(
      id: id ?? this.id,
      clientUuid: clientUuid ?? this.clientUuid,
      bytes: bytes ?? this.bytes,
      mimeType: mimeType ?? this.mimeType,
      lineId: lineId ?? this.lineId,
      patternId: patternId ?? this.patternId,
      nestingFrameNo: nestingFrameNo ?? this.nestingFrameNo,
      capturedAt: capturedAt ?? this.capturedAt,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (clientUuid.present) {
      map['client_uuid'] = Variable<String>(clientUuid.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<Uint8List>(bytes.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (lineId.present) {
      map['line_id'] = Variable<String>(lineId.value);
    }
    if (patternId.present) {
      map['pattern_id'] = Variable<String>(patternId.value);
    }
    if (nestingFrameNo.present) {
      map['nesting_frame_no'] = Variable<String>(nestingFrameNo.value);
    }
    if (capturedAt.present) {
      map['captured_at'] = Variable<DateTime>(capturedAt.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingPhotosCompanion(')
          ..write('id: $id, ')
          ..write('clientUuid: $clientUuid, ')
          ..write('bytes: $bytes, ')
          ..write('mimeType: $mimeType, ')
          ..write('lineId: $lineId, ')
          ..write('patternId: $patternId, ')
          ..write('nestingFrameNo: $nestingFrameNo, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $OutboxItemsTable outboxItems = $OutboxItemsTable(this);
  late final $CachedPartsTable cachedParts = $CachedPartsTable(this);
  late final $CachedPatternsTable cachedPatterns = $CachedPatternsTable(this);
  late final $CachedLinesTable cachedLines = $CachedLinesTable(this);
  late final $PendingPhotosTable pendingPhotos = $PendingPhotosTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    outboxItems,
    cachedParts,
    cachedPatterns,
    cachedLines,
    pendingPhotos,
  ];
}

typedef $$OutboxItemsTableCreateCompanionBuilder =
    OutboxItemsCompanion Function({
      Value<int> id,
      required String clientUuid,
      required OutboxKind kind,
      required String payload,
      Value<String> summary,
      Value<OutboxState> state,
      Value<int> attempts,
      Value<String?> lastError,
      Value<String?> errorCode,
      Value<String?> serverState,
      required DateTime queuedAt,
      required DateTime updatedAt,
      Value<DateTime?> nextAttemptAt,
      Value<String?> userId,
    });
typedef $$OutboxItemsTableUpdateCompanionBuilder =
    OutboxItemsCompanion Function({
      Value<int> id,
      Value<String> clientUuid,
      Value<OutboxKind> kind,
      Value<String> payload,
      Value<String> summary,
      Value<OutboxState> state,
      Value<int> attempts,
      Value<String?> lastError,
      Value<String?> errorCode,
      Value<String?> serverState,
      Value<DateTime> queuedAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> nextAttemptAt,
      Value<String?> userId,
    });

class $$OutboxItemsTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxItemsTable> {
  $$OutboxItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<OutboxKind, OutboxKind, int> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<OutboxState, OutboxState, int> get state =>
      $composableBuilder(
        column: $table.state,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverState => $composableBuilder(
    column: $table.serverState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get queuedAt => $composableBuilder(
    column: $table.queuedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxItemsTable> {
  $$OutboxItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverState => $composableBuilder(
    column: $table.serverState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get queuedAt => $composableBuilder(
    column: $table.queuedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxItemsTable> {
  $$OutboxItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<OutboxKind, int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumnWithTypeConverter<OutboxState, int> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);

  GeneratedColumn<String> get serverState => $composableBuilder(
    column: $table.serverState,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get queuedAt =>
      $composableBuilder(column: $table.queuedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);
}

class $$OutboxItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxItemsTable,
          OutboxRow,
          $$OutboxItemsTableFilterComposer,
          $$OutboxItemsTableOrderingComposer,
          $$OutboxItemsTableAnnotationComposer,
          $$OutboxItemsTableCreateCompanionBuilder,
          $$OutboxItemsTableUpdateCompanionBuilder,
          (
            OutboxRow,
            BaseReferences<_$AppDatabase, $OutboxItemsTable, OutboxRow>,
          ),
          OutboxRow,
          PrefetchHooks Function()
        > {
  $$OutboxItemsTableTableManager(_$AppDatabase db, $OutboxItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> clientUuid = const Value.absent(),
                Value<OutboxKind> kind = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String> summary = const Value.absent(),
                Value<OutboxState> state = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<String?> serverState = const Value.absent(),
                Value<DateTime> queuedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<String?> userId = const Value.absent(),
              }) => OutboxItemsCompanion(
                id: id,
                clientUuid: clientUuid,
                kind: kind,
                payload: payload,
                summary: summary,
                state: state,
                attempts: attempts,
                lastError: lastError,
                errorCode: errorCode,
                serverState: serverState,
                queuedAt: queuedAt,
                updatedAt: updatedAt,
                nextAttemptAt: nextAttemptAt,
                userId: userId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String clientUuid,
                required OutboxKind kind,
                required String payload,
                Value<String> summary = const Value.absent(),
                Value<OutboxState> state = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<String?> serverState = const Value.absent(),
                required DateTime queuedAt,
                required DateTime updatedAt,
                Value<DateTime?> nextAttemptAt = const Value.absent(),
                Value<String?> userId = const Value.absent(),
              }) => OutboxItemsCompanion.insert(
                id: id,
                clientUuid: clientUuid,
                kind: kind,
                payload: payload,
                summary: summary,
                state: state,
                attempts: attempts,
                lastError: lastError,
                errorCode: errorCode,
                serverState: serverState,
                queuedAt: queuedAt,
                updatedAt: updatedAt,
                nextAttemptAt: nextAttemptAt,
                userId: userId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxItemsTable,
      OutboxRow,
      $$OutboxItemsTableFilterComposer,
      $$OutboxItemsTableOrderingComposer,
      $$OutboxItemsTableAnnotationComposer,
      $$OutboxItemsTableCreateCompanionBuilder,
      $$OutboxItemsTableUpdateCompanionBuilder,
      (OutboxRow, BaseReferences<_$AppDatabase, $OutboxItemsTable, OutboxRow>),
      OutboxRow,
      PrefetchHooks Function()
    >;
typedef $$CachedPartsTableCreateCompanionBuilder =
    CachedPartsCompanion Function({
      required String id,
      required String unpaintedPn,
      Value<String?> paintedPn,
      required String description,
      Value<String?> colorShade,
      Value<String?> partType,
      Value<String?> station,
      Value<String?> rackCode,
      Value<bool> isBulky,
      Value<double> availableStock,
      required DateTime cachedAt,
      Value<int> rowid,
    });
typedef $$CachedPartsTableUpdateCompanionBuilder =
    CachedPartsCompanion Function({
      Value<String> id,
      Value<String> unpaintedPn,
      Value<String?> paintedPn,
      Value<String> description,
      Value<String?> colorShade,
      Value<String?> partType,
      Value<String?> station,
      Value<String?> rackCode,
      Value<bool> isBulky,
      Value<double> availableStock,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

class $$CachedPartsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedPartsTable> {
  $$CachedPartsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unpaintedPn => $composableBuilder(
    column: $table.unpaintedPn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paintedPn => $composableBuilder(
    column: $table.paintedPn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorShade => $composableBuilder(
    column: $table.colorShade,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get partType => $composableBuilder(
    column: $table.partType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get station => $composableBuilder(
    column: $table.station,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rackCode => $composableBuilder(
    column: $table.rackCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isBulky => $composableBuilder(
    column: $table.isBulky,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get availableStock => $composableBuilder(
    column: $table.availableStock,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedPartsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedPartsTable> {
  $$CachedPartsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unpaintedPn => $composableBuilder(
    column: $table.unpaintedPn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paintedPn => $composableBuilder(
    column: $table.paintedPn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorShade => $composableBuilder(
    column: $table.colorShade,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get partType => $composableBuilder(
    column: $table.partType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get station => $composableBuilder(
    column: $table.station,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rackCode => $composableBuilder(
    column: $table.rackCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isBulky => $composableBuilder(
    column: $table.isBulky,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get availableStock => $composableBuilder(
    column: $table.availableStock,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedPartsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedPartsTable> {
  $$CachedPartsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get unpaintedPn => $composableBuilder(
    column: $table.unpaintedPn,
    builder: (column) => column,
  );

  GeneratedColumn<String> get paintedPn =>
      $composableBuilder(column: $table.paintedPn, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get colorShade => $composableBuilder(
    column: $table.colorShade,
    builder: (column) => column,
  );

  GeneratedColumn<String> get partType =>
      $composableBuilder(column: $table.partType, builder: (column) => column);

  GeneratedColumn<String> get station =>
      $composableBuilder(column: $table.station, builder: (column) => column);

  GeneratedColumn<String> get rackCode =>
      $composableBuilder(column: $table.rackCode, builder: (column) => column);

  GeneratedColumn<bool> get isBulky =>
      $composableBuilder(column: $table.isBulky, builder: (column) => column);

  GeneratedColumn<double> get availableStock => $composableBuilder(
    column: $table.availableStock,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CachedPartsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedPartsTable,
          CachedPart,
          $$CachedPartsTableFilterComposer,
          $$CachedPartsTableOrderingComposer,
          $$CachedPartsTableAnnotationComposer,
          $$CachedPartsTableCreateCompanionBuilder,
          $$CachedPartsTableUpdateCompanionBuilder,
          (
            CachedPart,
            BaseReferences<_$AppDatabase, $CachedPartsTable, CachedPart>,
          ),
          CachedPart,
          PrefetchHooks Function()
        > {
  $$CachedPartsTableTableManager(_$AppDatabase db, $CachedPartsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedPartsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedPartsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedPartsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> unpaintedPn = const Value.absent(),
                Value<String?> paintedPn = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String?> colorShade = const Value.absent(),
                Value<String?> partType = const Value.absent(),
                Value<String?> station = const Value.absent(),
                Value<String?> rackCode = const Value.absent(),
                Value<bool> isBulky = const Value.absent(),
                Value<double> availableStock = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedPartsCompanion(
                id: id,
                unpaintedPn: unpaintedPn,
                paintedPn: paintedPn,
                description: description,
                colorShade: colorShade,
                partType: partType,
                station: station,
                rackCode: rackCode,
                isBulky: isBulky,
                availableStock: availableStock,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String unpaintedPn,
                Value<String?> paintedPn = const Value.absent(),
                required String description,
                Value<String?> colorShade = const Value.absent(),
                Value<String?> partType = const Value.absent(),
                Value<String?> station = const Value.absent(),
                Value<String?> rackCode = const Value.absent(),
                Value<bool> isBulky = const Value.absent(),
                Value<double> availableStock = const Value.absent(),
                required DateTime cachedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedPartsCompanion.insert(
                id: id,
                unpaintedPn: unpaintedPn,
                paintedPn: paintedPn,
                description: description,
                colorShade: colorShade,
                partType: partType,
                station: station,
                rackCode: rackCode,
                isBulky: isBulky,
                availableStock: availableStock,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedPartsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedPartsTable,
      CachedPart,
      $$CachedPartsTableFilterComposer,
      $$CachedPartsTableOrderingComposer,
      $$CachedPartsTableAnnotationComposer,
      $$CachedPartsTableCreateCompanionBuilder,
      $$CachedPartsTableUpdateCompanionBuilder,
      (
        CachedPart,
        BaseReferences<_$AppDatabase, $CachedPartsTable, CachedPart>,
      ),
      CachedPart,
      PrefetchHooks Function()
    >;
typedef $$CachedPatternsTableCreateCompanionBuilder =
    CachedPatternsCompanion Function({
      required String id,
      required String lineId,
      required String code,
      Value<String?> name,
      Value<double?> plannedSurface,
      Value<String?> shade,
      Value<bool> isSpecial,
      Value<bool> approved,
      Value<String> itemsJson,
      required DateTime cachedAt,
      Value<int> rowid,
    });
typedef $$CachedPatternsTableUpdateCompanionBuilder =
    CachedPatternsCompanion Function({
      Value<String> id,
      Value<String> lineId,
      Value<String> code,
      Value<String?> name,
      Value<double?> plannedSurface,
      Value<String?> shade,
      Value<bool> isSpecial,
      Value<bool> approved,
      Value<String> itemsJson,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

class $$CachedPatternsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedPatternsTable> {
  $$CachedPatternsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lineId => $composableBuilder(
    column: $table.lineId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get plannedSurface => $composableBuilder(
    column: $table.plannedSurface,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shade => $composableBuilder(
    column: $table.shade,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSpecial => $composableBuilder(
    column: $table.isSpecial,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get approved => $composableBuilder(
    column: $table.approved,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemsJson => $composableBuilder(
    column: $table.itemsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedPatternsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedPatternsTable> {
  $$CachedPatternsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lineId => $composableBuilder(
    column: $table.lineId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get plannedSurface => $composableBuilder(
    column: $table.plannedSurface,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shade => $composableBuilder(
    column: $table.shade,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSpecial => $composableBuilder(
    column: $table.isSpecial,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get approved => $composableBuilder(
    column: $table.approved,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemsJson => $composableBuilder(
    column: $table.itemsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedPatternsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedPatternsTable> {
  $$CachedPatternsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get lineId =>
      $composableBuilder(column: $table.lineId, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get plannedSurface => $composableBuilder(
    column: $table.plannedSurface,
    builder: (column) => column,
  );

  GeneratedColumn<String> get shade =>
      $composableBuilder(column: $table.shade, builder: (column) => column);

  GeneratedColumn<bool> get isSpecial =>
      $composableBuilder(column: $table.isSpecial, builder: (column) => column);

  GeneratedColumn<bool> get approved =>
      $composableBuilder(column: $table.approved, builder: (column) => column);

  GeneratedColumn<String> get itemsJson =>
      $composableBuilder(column: $table.itemsJson, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CachedPatternsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedPatternsTable,
          CachedPattern,
          $$CachedPatternsTableFilterComposer,
          $$CachedPatternsTableOrderingComposer,
          $$CachedPatternsTableAnnotationComposer,
          $$CachedPatternsTableCreateCompanionBuilder,
          $$CachedPatternsTableUpdateCompanionBuilder,
          (
            CachedPattern,
            BaseReferences<_$AppDatabase, $CachedPatternsTable, CachedPattern>,
          ),
          CachedPattern,
          PrefetchHooks Function()
        > {
  $$CachedPatternsTableTableManager(
    _$AppDatabase db,
    $CachedPatternsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedPatternsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedPatternsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedPatternsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> lineId = const Value.absent(),
                Value<String> code = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<double?> plannedSurface = const Value.absent(),
                Value<String?> shade = const Value.absent(),
                Value<bool> isSpecial = const Value.absent(),
                Value<bool> approved = const Value.absent(),
                Value<String> itemsJson = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedPatternsCompanion(
                id: id,
                lineId: lineId,
                code: code,
                name: name,
                plannedSurface: plannedSurface,
                shade: shade,
                isSpecial: isSpecial,
                approved: approved,
                itemsJson: itemsJson,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String lineId,
                required String code,
                Value<String?> name = const Value.absent(),
                Value<double?> plannedSurface = const Value.absent(),
                Value<String?> shade = const Value.absent(),
                Value<bool> isSpecial = const Value.absent(),
                Value<bool> approved = const Value.absent(),
                Value<String> itemsJson = const Value.absent(),
                required DateTime cachedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedPatternsCompanion.insert(
                id: id,
                lineId: lineId,
                code: code,
                name: name,
                plannedSurface: plannedSurface,
                shade: shade,
                isSpecial: isSpecial,
                approved: approved,
                itemsJson: itemsJson,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedPatternsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedPatternsTable,
      CachedPattern,
      $$CachedPatternsTableFilterComposer,
      $$CachedPatternsTableOrderingComposer,
      $$CachedPatternsTableAnnotationComposer,
      $$CachedPatternsTableCreateCompanionBuilder,
      $$CachedPatternsTableUpdateCompanionBuilder,
      (
        CachedPattern,
        BaseReferences<_$AppDatabase, $CachedPatternsTable, CachedPattern>,
      ),
      CachedPattern,
      PrefetchHooks Function()
    >;
typedef $$CachedLinesTableCreateCompanionBuilder =
    CachedLinesCompanion Function({
      required String id,
      required String code,
      required String name,
      Value<int> yellowThreshold,
      Value<int> redThreshold,
      Value<bool> runsDriveConsumption,
      Value<int> sortOrder,
      required DateTime cachedAt,
      Value<int> rowid,
    });
typedef $$CachedLinesTableUpdateCompanionBuilder =
    CachedLinesCompanion Function({
      Value<String> id,
      Value<String> code,
      Value<String> name,
      Value<int> yellowThreshold,
      Value<int> redThreshold,
      Value<bool> runsDriveConsumption,
      Value<int> sortOrder,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

class $$CachedLinesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedLinesTable> {
  $$CachedLinesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get yellowThreshold => $composableBuilder(
    column: $table.yellowThreshold,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get redThreshold => $composableBuilder(
    column: $table.redThreshold,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get runsDriveConsumption => $composableBuilder(
    column: $table.runsDriveConsumption,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedLinesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedLinesTable> {
  $$CachedLinesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get yellowThreshold => $composableBuilder(
    column: $table.yellowThreshold,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get redThreshold => $composableBuilder(
    column: $table.redThreshold,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get runsDriveConsumption => $composableBuilder(
    column: $table.runsDriveConsumption,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedLinesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedLinesTable> {
  $$CachedLinesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get yellowThreshold => $composableBuilder(
    column: $table.yellowThreshold,
    builder: (column) => column,
  );

  GeneratedColumn<int> get redThreshold => $composableBuilder(
    column: $table.redThreshold,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get runsDriveConsumption => $composableBuilder(
    column: $table.runsDriveConsumption,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CachedLinesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedLinesTable,
          CachedLine,
          $$CachedLinesTableFilterComposer,
          $$CachedLinesTableOrderingComposer,
          $$CachedLinesTableAnnotationComposer,
          $$CachedLinesTableCreateCompanionBuilder,
          $$CachedLinesTableUpdateCompanionBuilder,
          (
            CachedLine,
            BaseReferences<_$AppDatabase, $CachedLinesTable, CachedLine>,
          ),
          CachedLine,
          PrefetchHooks Function()
        > {
  $$CachedLinesTableTableManager(_$AppDatabase db, $CachedLinesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedLinesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedLinesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedLinesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> code = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> yellowThreshold = const Value.absent(),
                Value<int> redThreshold = const Value.absent(),
                Value<bool> runsDriveConsumption = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedLinesCompanion(
                id: id,
                code: code,
                name: name,
                yellowThreshold: yellowThreshold,
                redThreshold: redThreshold,
                runsDriveConsumption: runsDriveConsumption,
                sortOrder: sortOrder,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String code,
                required String name,
                Value<int> yellowThreshold = const Value.absent(),
                Value<int> redThreshold = const Value.absent(),
                Value<bool> runsDriveConsumption = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                required DateTime cachedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedLinesCompanion.insert(
                id: id,
                code: code,
                name: name,
                yellowThreshold: yellowThreshold,
                redThreshold: redThreshold,
                runsDriveConsumption: runsDriveConsumption,
                sortOrder: sortOrder,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedLinesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedLinesTable,
      CachedLine,
      $$CachedLinesTableFilterComposer,
      $$CachedLinesTableOrderingComposer,
      $$CachedLinesTableAnnotationComposer,
      $$CachedLinesTableCreateCompanionBuilder,
      $$CachedLinesTableUpdateCompanionBuilder,
      (
        CachedLine,
        BaseReferences<_$AppDatabase, $CachedLinesTable, CachedLine>,
      ),
      CachedLine,
      PrefetchHooks Function()
    >;
typedef $$PendingPhotosTableCreateCompanionBuilder =
    PendingPhotosCompanion Function({
      Value<int> id,
      required String clientUuid,
      required Uint8List bytes,
      Value<String> mimeType,
      Value<String?> lineId,
      Value<String?> patternId,
      Value<String?> nestingFrameNo,
      required DateTime capturedAt,
      Value<int> attempts,
      Value<String?> lastError,
    });
typedef $$PendingPhotosTableUpdateCompanionBuilder =
    PendingPhotosCompanion Function({
      Value<int> id,
      Value<String> clientUuid,
      Value<Uint8List> bytes,
      Value<String> mimeType,
      Value<String?> lineId,
      Value<String?> patternId,
      Value<String?> nestingFrameNo,
      Value<DateTime> capturedAt,
      Value<int> attempts,
      Value<String?> lastError,
    });

class $$PendingPhotosTableFilterComposer
    extends Composer<_$AppDatabase, $PendingPhotosTable> {
  $$PendingPhotosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lineId => $composableBuilder(
    column: $table.lineId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get patternId => $composableBuilder(
    column: $table.patternId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nestingFrameNo => $composableBuilder(
    column: $table.nestingFrameNo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingPhotosTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingPhotosTable> {
  $$PendingPhotosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lineId => $composableBuilder(
    column: $table.lineId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get patternId => $composableBuilder(
    column: $table.patternId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nestingFrameNo => $composableBuilder(
    column: $table.nestingFrameNo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingPhotosTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingPhotosTable> {
  $$PendingPhotosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get clientUuid => $composableBuilder(
    column: $table.clientUuid,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<String> get lineId =>
      $composableBuilder(column: $table.lineId, builder: (column) => column);

  GeneratedColumn<String> get patternId =>
      $composableBuilder(column: $table.patternId, builder: (column) => column);

  GeneratedColumn<String> get nestingFrameNo => $composableBuilder(
    column: $table.nestingFrameNo,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$PendingPhotosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingPhotosTable,
          PendingPhoto,
          $$PendingPhotosTableFilterComposer,
          $$PendingPhotosTableOrderingComposer,
          $$PendingPhotosTableAnnotationComposer,
          $$PendingPhotosTableCreateCompanionBuilder,
          $$PendingPhotosTableUpdateCompanionBuilder,
          (
            PendingPhoto,
            BaseReferences<_$AppDatabase, $PendingPhotosTable, PendingPhoto>,
          ),
          PendingPhoto,
          PrefetchHooks Function()
        > {
  $$PendingPhotosTableTableManager(_$AppDatabase db, $PendingPhotosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingPhotosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingPhotosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingPhotosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> clientUuid = const Value.absent(),
                Value<Uint8List> bytes = const Value.absent(),
                Value<String> mimeType = const Value.absent(),
                Value<String?> lineId = const Value.absent(),
                Value<String?> patternId = const Value.absent(),
                Value<String?> nestingFrameNo = const Value.absent(),
                Value<DateTime> capturedAt = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => PendingPhotosCompanion(
                id: id,
                clientUuid: clientUuid,
                bytes: bytes,
                mimeType: mimeType,
                lineId: lineId,
                patternId: patternId,
                nestingFrameNo: nestingFrameNo,
                capturedAt: capturedAt,
                attempts: attempts,
                lastError: lastError,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String clientUuid,
                required Uint8List bytes,
                Value<String> mimeType = const Value.absent(),
                Value<String?> lineId = const Value.absent(),
                Value<String?> patternId = const Value.absent(),
                Value<String?> nestingFrameNo = const Value.absent(),
                required DateTime capturedAt,
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
              }) => PendingPhotosCompanion.insert(
                id: id,
                clientUuid: clientUuid,
                bytes: bytes,
                mimeType: mimeType,
                lineId: lineId,
                patternId: patternId,
                nestingFrameNo: nestingFrameNo,
                capturedAt: capturedAt,
                attempts: attempts,
                lastError: lastError,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingPhotosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingPhotosTable,
      PendingPhoto,
      $$PendingPhotosTableFilterComposer,
      $$PendingPhotosTableOrderingComposer,
      $$PendingPhotosTableAnnotationComposer,
      $$PendingPhotosTableCreateCompanionBuilder,
      $$PendingPhotosTableUpdateCompanionBuilder,
      (
        PendingPhoto,
        BaseReferences<_$AppDatabase, $PendingPhotosTable, PendingPhoto>,
      ),
      PendingPhoto,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$OutboxItemsTableTableManager get outboxItems =>
      $$OutboxItemsTableTableManager(_db, _db.outboxItems);
  $$CachedPartsTableTableManager get cachedParts =>
      $$CachedPartsTableTableManager(_db, _db.cachedParts);
  $$CachedPatternsTableTableManager get cachedPatterns =>
      $$CachedPatternsTableTableManager(_db, _db.cachedPatterns);
  $$CachedLinesTableTableManager get cachedLines =>
      $$CachedLinesTableTableManager(_db, _db.cachedLines);
  $$PendingPhotosTableTableManager get pendingPhotos =>
      $$PendingPhotosTableTableManager(_db, _db.pendingPhotos);
}
